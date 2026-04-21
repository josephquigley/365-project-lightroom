# Lightroom Classic 365 Calendar Plugin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Lightroom Classic plugin that opens a month-grid calendar dialog showing thumbnails on days with photos and tinted empty cells on days without.

**Architecture:** Five-module Lua plugin inside a `.lrplugin` bundle. Pure-Lua `CalendarModel` handles date binning (TDD-tested outside Lightroom). `CollectionReader` isolates catalog I/O. `CalendarView` builds the `LrView` tree. `ShowCalendarDialog` owns the navigation loop that re-presents the modal on prev/next. `Info.lua` registers the menu entry.

**Tech Stack:** Lua 5.1 (Lightroom's embedded version), Lightroom Classic SDK (`LrView`, `LrDialogs`, `LrTasks`, `LrApplication`, `LrColor`), macOS `lua` interpreter for running unit tests.

**Design spec:** [docs/superpowers/specs/2026-04-21-lightroom-plugin-calendar-design.md](../specs/2026-04-21-lightroom-plugin-calendar-design.md)

---

## File structure

| Path | Created by | Responsibility |
|---|---|---|
| `CLAUDE.md` | Task 1 | Agent directives for this repo |
| `README.md` | Task 1 | Human-facing project overview |
| `.gitignore` | Task 1 | Ignore macOS/editor cruft |
| `365Calendar.lrplugin/Info.lua` | Task 2 | Plugin manifest + menu registration |
| `365Calendar.lrplugin/CalendarModel.lua` | Task 3–11 | Pure-Lua date binning and month queries |
| `365Calendar.lrplugin/CollectionReader.lua` | Task 12 | Loads `LrPhoto`s from a collection |
| `365Calendar.lrplugin/CalendarView.lua` | Task 13–17 | Builds the `LrView` UI tree |
| `365Calendar.lrplugin/ShowCalendarDialog.lua` | Task 18 | Entry point, navigation loop |
| `365Calendar.lrplugin/strings/TranslatedStrings.txt` | Task 19 | Localized UI strings |
| `tests/test_calendar_model.lua` | Task 3 onward | Unit tests for `CalendarModel` |
| `tests/run_tests.sh` | Task 3 | Test runner entry point |

Lua modules each return their own module table. `CalendarModel` has zero LrSDK dependencies so it can be loaded from a plain `lua` interpreter. `CollectionReader`, `CalendarView`, and `ShowCalendarDialog` use `import "Lr…"` at the top and are only loadable inside Lightroom.

---

## Task 1: Project scaffolding, CLAUDE.md, git init

**Files:**
- Create: `CLAUDE.md`
- Create: `README.md`
- Create: `.gitignore`
- Create: `365Calendar.lrplugin/` (directory)
- Create: `365Calendar.lrplugin/strings/` (directory)
- Create: `tests/` (directory)

- [ ] **Step 1: Create `.gitignore`**

```gitignore
.DS_Store
*.swp
*.swo
*~
.idea/
.vscode/
```

- [ ] **Step 2: Create `CLAUDE.md`**

```markdown
# 365 Project — Agent Directives

Tools for the 365 Project photography challenge — a year-long daily-photo
discipline.

## Active scope

Only the **Lightroom Classic plugin** (`365Calendar.lrplugin/`) is in active
development. All of the following are deliberately deferred — do not scaffold
or touch code for them without explicit user request:

- Lightroom CC / Cloud plugin surface (no equivalent API; not supported)
- Direct `.lrcat` SQLite reading
- macOS / iOS companion apps
- Smart-collection support
- Quarter-view and year-view calendar layouts
- Click interactions on calendar cells

## Repository layout

- `365Calendar.lrplugin/` — the plugin bundle. Loads directly into Lightroom.
- `tests/` — plain-Lua unit tests for pure-Lua modules.
- `docs/superpowers/specs/` — approved design documents. Consult before making
  behavioral changes.
- `docs/superpowers/plans/` — implementation plans that produced this repo.

## Code style

- Lua 5.1 — Lightroom's embedded version. Do NOT use 5.2+ syntax (no `goto`,
  no integer/float split, no `//` integer division).
- 2-space indentation.
- `snake_case` for local functions/variables. Module table returned at EOF.
- Every LrSDK dependency declared at the top of the file:
  `local LrView = import "LrView"`.
- Keep pure-Lua logic in `CalendarModel.lua` so it stays unit-testable.

## Build and test

There is no build step. Lightroom loads `.lrplugin` bundles directly.

**Unit tests** (run from the repo root):

    bash tests/run_tests.sh

This executes the pure-Lua tests against the system `lua` interpreter. Tests
must pass before commits that touch `CalendarModel.lua`.

**Manual smoke test in Lightroom Classic:**

1. Symlink the plugin into Lightroom's modules folder:

       ln -s "$PWD/365Calendar.lrplugin" \
         "$HOME/Library/Application Support/Adobe/Lightroom/Modules/365Calendar.lrplugin"

2. Launch Lightroom Classic.
3. `File > Plug-in Manager…` — confirm the plugin appears as "Enabled".
4. `Library > Plug-in Extras > Show 365 Calendar…` — the dialog should open.

## Collaboration workflow

- **TDD** for `CalendarModel.lua`: red test → minimal implementation → green →
  commit. One behavior per commit.
- UI code (`CalendarView.lua`, `ShowCalendarDialog.lua`) cannot be unit-tested
  without Lightroom. Verify manually; record the steps you ran in the commit
  message.
- Commits are small — one concern each.

## LrSDK references

Consult the Lightroom Classic SDK Programmer's Guide for `LrView` primitives
(`f:place`, `f:row`, `f:column`, `f:popup_menu`, `f:catalog_photo`,
`f:static_text`, `f:push_button`, `f:view`, `f:scrolled_view`) and
`LrDialogs.presentModalDialog` mechanics.
```

- [ ] **Step 3: Create `README.md`**

```markdown
# 365 Project — Lightroom Plugin

A Lightroom Classic plugin that shows a month-grid calendar view of a
collection, with thumbnails on days with photos and tinted empty cells on
days without. Helps photographers running the 365 Project visually identify
missing days.

See [`CLAUDE.md`](./CLAUDE.md) for contributor setup.
See [`docs/superpowers/specs/`](./docs/superpowers/specs/) for design docs.
```

- [ ] **Step 4: Create plugin and tests directory skeletons**

Run:

    mkdir -p 365Calendar.lrplugin/strings tests

- [ ] **Step 5: Initialize git and make initial commit**

Run:

    git init
    git add .gitignore CLAUDE.md README.md docs/
    git commit -m "chore: initial scaffolding and agent directives"

Expected: a first commit on `main` (or `master`) with the four files and the
already-present `docs/superpowers/specs/…-design.md` and
`docs/superpowers/plans/…-calendar.md`.

---

## Task 2: Plugin manifest (`Info.lua`)

**Files:**
- Create: `365Calendar.lrplugin/Info.lua`

No unit test — the manifest is declarative and validated by Lightroom at load time.

- [ ] **Step 1: Write `Info.lua`**

```lua
return {
  LrSdkVersion = 10.0,
  LrSdkMinimumVersion = 6.0,

  LrToolkitIdentifier = "com.threesixtyfiveproject.calendar",
  LrPluginName = LOC "$$$/365Calendar/PluginName=365 Project Calendar",

  LrLibraryMenuItems = {
    {
      title = LOC "$$$/365Calendar/MenuItem=Show 365 Calendar...",
      file  = "ShowCalendarDialog.lua",
    },
  },

  VERSION = { major = 0, minor = 1, revision = 0, build = 1 },
}
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/Info.lua
    git commit -m "feat(plugin): add Info.lua manifest and menu entry"

---

## Task 3: Test harness + CalendarModel skeleton

Set up a minimal Lua test harness and a passing smoke test that the module
loads. This bootstraps TDD for every subsequent CalendarModel task.

**Files:**
- Create: `tests/test_calendar_model.lua`
- Create: `tests/run_tests.sh`
- Create: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Create test harness and first failing test**

Create `tests/test_calendar_model.lua`:

```lua
-- Make the plugin modules importable. Tests are run from repo root.
package.path = "./365Calendar.lrplugin/?.lua;" .. package.path

local CalendarModel = require("CalendarModel")

local passed, failed = 0, 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    passed = passed + 1
    print("  PASS: " .. name)
  else
    failed = failed + 1
    print("  FAIL: " .. name)
    print("    " .. tostring(err))
  end
end

local function assert_equal(actual, expected, msg)
  if actual ~= expected then
    error((msg or "values differ") ..
      string.format(" (expected %s, got %s)", tostring(expected), tostring(actual)), 2)
  end
end

local function assert_nil(x, msg)
  if x ~= nil then
    error((msg or "expected nil") .. " (got " .. tostring(x) .. ")", 2)
  end
end

-- Build a minimal LrPhoto stub: `getRawMetadata(key)` returns whatever
-- was passed in, keyed by metadata name.
local function stubPhoto(metadata)
  return {
    getRawMetadata = function(self, key) return metadata[key] end,
  }
end

-- Cocoa-epoch offset: Cocoa = Unix - 978307200.
local function cocoaAt(y, m, d, h, min, sec)
  local unix = os.time({
    year = y, month = m, day = d,
    hour = h or 12, min = min or 0, sec = sec or 0,
  })
  return unix - 978307200
end

-- ---------------------------------------------------------------
-- Smoke test: the module loads and exposes its expected interface
-- ---------------------------------------------------------------

test("module exposes new and rollMonth", function()
  assert_equal(type(CalendarModel.new), "function", "new should be a function")
  assert_equal(type(CalendarModel.rollMonth), "function", "rollMonth should be a function")
end)

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
```

- [ ] **Step 2: Create `tests/run_tests.sh`**

```bash
#!/usr/bin/env bash
# Runs pure-Lua unit tests. Expects `lua` on PATH.
set -e
cd "$(dirname "$0")/.."
lua tests/test_calendar_model.lua
```

Then make it executable:

    chmod +x tests/run_tests.sh

- [ ] **Step 3: Run the test — expect it to FAIL**

Run:

    bash tests/run_tests.sh

Expected: error loading `CalendarModel` (module not found or empty). Failure
confirms the test infrastructure is actually exercising the module.

- [ ] **Step 4: Create minimal `CalendarModel.lua` to make the smoke test pass**

```lua
-- CalendarModel: pure-Lua date binning for the 365 calendar view.
-- No Lightroom SDK imports in this file.

local M = {}

function M.new(photos)
  error("not yet implemented", 2)
end

function M.rollMonth(year, month, delta)
  error("not yet implemented", 2)
end

return M
```

- [ ] **Step 5: Run the test — expect it to PASS**

Run:

    bash tests/run_tests.sh

Expected output ends with `1 passed, 0 failed` and exit code 0.

- [ ] **Step 6: Commit**

Run:

    git add tests/ 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "test(model): add test harness and CalendarModel skeleton"

---

## Task 4: `rollMonth` helper (TDD)

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing tests**

Append to `tests/test_calendar_model.lua` **before** the final `print`/`os.exit`
lines:

```lua
-- ---------------------------------------------------------------
-- rollMonth: month arithmetic with year rollover
-- ---------------------------------------------------------------

test("rollMonth: simple forward step", function()
  local y, m = CalendarModel.rollMonth(2026, 4, 1)
  assert_equal(y, 2026)
  assert_equal(m, 5)
end)

test("rollMonth: simple backward step", function()
  local y, m = CalendarModel.rollMonth(2026, 4, -1)
  assert_equal(y, 2026)
  assert_equal(m, 3)
end)

test("rollMonth: December forward rolls year", function()
  local y, m = CalendarModel.rollMonth(2026, 12, 1)
  assert_equal(y, 2027)
  assert_equal(m, 1)
end)

test("rollMonth: January backward rolls year", function()
  local y, m = CalendarModel.rollMonth(2026, 1, -1)
  assert_equal(y, 2025)
  assert_equal(m, 12)
end)
```

- [ ] **Step 2: Run tests — expect 4 new FAIL, 1 PASS**

Run:

    bash tests/run_tests.sh

Expected: `1 passed, 4 failed` (the new tests all fail with "not yet implemented").

- [ ] **Step 3: Implement `rollMonth`**

Replace the body of `rollMonth` in `365Calendar.lrplugin/CalendarModel.lua`:

```lua
function M.rollMonth(year, month, delta)
  -- Convert (year, month) into a 0-indexed month count, shift, convert back.
  local zeroBased = (year * 12 + (month - 1)) + delta
  local newYear = math.floor(zeroBased / 12)
  local newMonth = (zeroBased - newYear * 12) + 1
  return newYear, newMonth
end
```

- [ ] **Step 4: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `5 passed, 0 failed`.

- [ ] **Step 5: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): add rollMonth with year rollover"

---

## Task 5: `_cocoaToLocalDate` (TDD)

Convert a Cocoa-epoch seconds value into a `{year, month, day}` triple in local
time. Internal helper but exposed on the module for testing.

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing test**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- _cocoaToLocalDate
-- ---------------------------------------------------------------

test("_cocoaToLocalDate: round-trips a known local date", function()
  -- Build a Cocoa-seconds value for 2026-04-21 12:00:00 local, then convert.
  local cs = cocoaAt(2026, 4, 21, 12)
  local y, mo, d = CalendarModel._cocoaToLocalDate(cs)
  assert_equal(y, 2026)
  assert_equal(mo, 4)
  assert_equal(d, 21)
end)

test("_cocoaToLocalDate: works near midnight boundary", function()
  -- 23:30 local on the 15th must stay on the 15th.
  local cs = cocoaAt(2026, 4, 15, 23, 30, 0)
  local y, mo, d = CalendarModel._cocoaToLocalDate(cs)
  assert_equal(y, 2026)
  assert_equal(mo, 4)
  assert_equal(d, 15)
end)
```

- [ ] **Step 2: Run tests — expect the new tests to FAIL**

Run:

    bash tests/run_tests.sh

Expected: 2 new failures ("attempt to call field '_cocoaToLocalDate' (a nil value)").

- [ ] **Step 3: Implement `_cocoaToLocalDate`**

Add to `365Calendar.lrplugin/CalendarModel.lua`, above the `M.new` stub:

```lua
-- Cocoa epoch (2001-01-01 UTC) offset from Unix epoch (1970-01-01 UTC).
local COCOA_UNIX_OFFSET = 978307200

-- Convert Cocoa-epoch seconds (as returned by
-- `photo:getRawMetadata("dateTimeOriginal")`) to a local calendar (year, month, day).
function M._cocoaToLocalDate(cocoaSeconds)
  local unix = cocoaSeconds + COCOA_UNIX_OFFSET
  local t = os.date("*t", unix)
  return t.year, t.month, t.day
end
```

- [ ] **Step 4: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `7 passed, 0 failed`.

- [ ] **Step 5: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): add Cocoa-seconds to local-date conversion"

---

## Task 6: `CalendarModel.new` bins photos by day (TDD)

Constructing a model reads each photo's `dateTimeOriginal`, converts to a local
date, and bins into an internal `{year, month, day} → {photos sorted by time}`
map.

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing tests**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- CalendarModel.new: binning
-- ---------------------------------------------------------------

test("new: returns an object with cellsForMonth method", function()
  local m = CalendarModel.new({})
  assert_equal(type(m.cellsForMonth), "function")
end)

test("new: bins a single photo into its date key", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  local bin = m:_binFor(2026, 4, 15)
  assert_equal(#bin, 1)
  assert_equal(bin[1], p)
end)

test("new: photos on different days go into separate bins", function()
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local p2 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 16, 10) })
  local m = CalendarModel.new({ p1, p2 })
  assert_equal(#m:_binFor(2026, 4, 15), 1)
  assert_equal(#m:_binFor(2026, 4, 16), 1)
end)
```

- [ ] **Step 2: Run tests — expect 3 FAIL**

Run:

    bash tests/run_tests.sh

Expected: 3 failures.

- [ ] **Step 3: Implement `M.new`**

Replace the `M.new` stub in `365Calendar.lrplugin/CalendarModel.lua`:

```lua
local function dayKey(y, m, d)
  return string.format("%04d-%02d-%02d", y, m, d)
end

local Model = {}
Model.__index = Model

function Model:_binFor(year, month, day)
  return self._bins[dayKey(year, month, day)] or {}
end

function M.new(photos)
  local bins = {}
  for _, photo in ipairs(photos) do
    local cs = photo:getRawMetadata("dateTimeOriginal")
    if cs then
      local y, mo, d = M._cocoaToLocalDate(cs)
      local key = dayKey(y, mo, d)
      bins[key] = bins[key] or {}
      table.insert(bins[key], photo)
    end
  end
  local self = setmetatable({ _bins = bins }, Model)
  return self
end
```

- [ ] **Step 4: Stub `cellsForMonth` so the "exposes method" test passes**

Append to `365Calendar.lrplugin/CalendarModel.lua`, inside the file (before
`return M`):

```lua
function Model:cellsForMonth(year, month)
  error("not yet implemented", 2)
end
```

- [ ] **Step 5: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `10 passed, 0 failed`.

- [ ] **Step 6: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): bin photos by local-date in CalendarModel.new"

---

## Task 7: `cellsForMonth` — empty and single-photo cases (TDD)

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing tests**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- cellsForMonth: shape + simple cases
-- ---------------------------------------------------------------

test("cellsForMonth: April has 30 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(#cells, 30)
end)

test("cellsForMonth: July has 31 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 7)
  assert_equal(#cells, 31)
end)

test("cellsForMonth: cells have day, primary, extras fields", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[1].day, 1)
  assert_equal(cells[15].day, 15)
  assert_nil(cells[1].primary)
  assert_equal(cells[1].extras, 0)
end)

test("cellsForMonth: single photo becomes primary of that day", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, p)
  assert_equal(cells[15].extras, 0)
end)

test("cellsForMonth: photos outside month do not appear", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 3, 31, 10) })
  local m = CalendarModel.new({ p })
  local cells = m:cellsForMonth(2026, 4)
  for _, c in ipairs(cells) do
    assert_nil(c.primary)
  end
end)
```

- [ ] **Step 2: Run tests — expect 5 FAIL**

Run:

    bash tests/run_tests.sh

Expected: 5 failures.

- [ ] **Step 3: Implement `cellsForMonth`**

Replace the `Model:cellsForMonth` stub in `365Calendar.lrplugin/CalendarModel.lua`:

```lua
-- Returns the number of days in the given (year, month) using os.time/os.date.
-- Trick: day 0 of month+1 is the last day of month.
local function daysInMonth(year, month)
  local nextMonth, nextYear = month + 1, year
  if nextMonth > 12 then nextMonth, nextYear = 1, year + 1 end
  local t = os.date("*t", os.time({ year = nextYear, month = nextMonth, day = 0, hour = 12 }))
  return t.day
end

function Model:cellsForMonth(year, month)
  local n = daysInMonth(year, month)
  local cells = {}
  for day = 1, n do
    local bin = self:_binFor(year, month, day)
    cells[day] = {
      day     = day,
      primary = bin[1],
      extras  = math.max(#bin - 1, 0),
    }
  end
  return cells
end
```

- [ ] **Step 4: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `15 passed, 0 failed`.

- [ ] **Step 5: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): cellsForMonth with day count and primary"

---

## Task 8: Multiple photos per day — primary = earliest, extras = count-1 (TDD)

Within a day, the earliest-captured photo is `primary`; `extras` is the count
of additional photos. Order inside a bin must be sorted ascending by capture
time.

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing tests**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- cellsForMonth: multi-photo days
-- ---------------------------------------------------------------

test("cellsForMonth: three photos same day -> primary earliest, extras=2", function()
  local morning = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 8) })
  local noon    = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 12) })
  local evening = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 20) })
  -- Pass in arbitrary order to confirm sorting.
  local m = CalendarModel.new({ evening, morning, noon })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, morning)
  assert_equal(cells[15].extras, 2)
end)
```

- [ ] **Step 2: Run test — expect FAIL**

Run:

    bash tests/run_tests.sh

Expected: `primary` is whichever photo was inserted first by the unsorted `new`.

- [ ] **Step 3: Sort each bin by capture time in `M.new`**

In `365Calendar.lrplugin/CalendarModel.lua`, modify `M.new` to sort each bin
after collecting. Replace the existing `M.new` with:

```lua
function M.new(photos)
  local bins = {}
  for _, photo in ipairs(photos) do
    local cs = photo:getRawMetadata("dateTimeOriginal")
    if cs then
      local y, mo, d = M._cocoaToLocalDate(cs)
      local key = dayKey(y, mo, d)
      bins[key] = bins[key] or {}
      table.insert(bins[key], photo)
    end
  end
  for _, bin in pairs(bins) do
    table.sort(bin, function(a, b)
      return a:getRawMetadata("dateTimeOriginal") < b:getRawMetadata("dateTimeOriginal")
    end)
  end
  local self = setmetatable({ _bins = bins }, Model)
  return self
end
```

- [ ] **Step 4: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `16 passed, 0 failed`.

- [ ] **Step 5: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): sort daily bins so primary is earliest capture"

---

## Task 9: Skip photos without `dateTimeOriginal` (TDD)

Photos lacking capture time are silently skipped — they don't land on any day
and don't inflate any extras count.

**Files:**
- Modify: `tests/test_calendar_model.lua`

No code change needed; the existing `if cs then` branch in `M.new` already
skips. This task adds the test that pins the behavior.

- [ ] **Step 1: Add test**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- Photos without dateTimeOriginal
-- ---------------------------------------------------------------

test("new: photos without dateTimeOriginal are skipped", function()
  local good    = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local missing = stubPhoto({ dateTimeOriginal = nil })
  local m = CalendarModel.new({ good, missing })
  local cells = m:cellsForMonth(2026, 4)
  assert_equal(cells[15].primary, good)
  assert_equal(cells[15].extras, 0)  -- missing did not inflate extras
end)
```

- [ ] **Step 2: Run tests — expect PASS immediately**

Run:

    bash tests/run_tests.sh

Expected: `17 passed, 0 failed`.

- [ ] **Step 3: Commit**

Run:

    git add tests/test_calendar_model.lua
    git commit -m "test(model): pin skip-behavior for photos without capture time"

---

## Task 10: Leap February (TDD)

**Files:**
- Modify: `tests/test_calendar_model.lua`

- [ ] **Step 1: Add test**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- Leap February
-- ---------------------------------------------------------------

test("cellsForMonth: February 2024 has 29 cells (leap year)", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2024, 2)
  assert_equal(#cells, 29)
end)

test("cellsForMonth: February 2025 has 28 cells", function()
  local m = CalendarModel.new({})
  local cells = m:cellsForMonth(2025, 2)
  assert_equal(#cells, 28)
end)
```

- [ ] **Step 2: Run tests — expect PASS immediately**

Run:

    bash tests/run_tests.sh

Expected: `19 passed, 0 failed`.

- [ ] **Step 3: Commit**

Run:

    git add tests/test_calendar_model.lua
    git commit -m "test(model): verify leap-February day count"

---

## Task 11: `firstWeekdayOfMonth` helper (TDD)

`CalendarView` needs to know how many leading blank cells to emit. This helper
returns the weekday (1=Sunday, 7=Saturday) of day 1 of a given month.

**Files:**
- Modify: `tests/test_calendar_model.lua`
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

- [ ] **Step 1: Add failing tests**

Append before the final `print`/`os.exit`:

```lua
-- ---------------------------------------------------------------
-- firstWeekdayOfMonth: 1=Sunday..7=Saturday
-- ---------------------------------------------------------------

test("firstWeekdayOfMonth: April 2026 starts on Wednesday (4)", function()
  assert_equal(CalendarModel.firstWeekdayOfMonth(2026, 4), 4)
end)

test("firstWeekdayOfMonth: February 2026 starts on Sunday (1)", function()
  assert_equal(CalendarModel.firstWeekdayOfMonth(2026, 2), 1)
end)
```

Note on values: April 2026's first is Wed (Apr 1 2026); February 2026's first
is Sun (Feb 1 2026). If `os.date` weekday values differ on your platform,
verify with `os.date("*t", os.time{year=2026,month=4,day=1,hour=12}).wday`.

- [ ] **Step 2: Run tests — expect FAIL**

Run:

    bash tests/run_tests.sh

Expected: 2 new failures.

- [ ] **Step 3: Implement**

Add to `365Calendar.lrplugin/CalendarModel.lua` above `return M`:

```lua
-- Returns the weekday of day 1 of the given month, with 1=Sunday..7=Saturday.
function M.firstWeekdayOfMonth(year, month)
  local t = os.date("*t", os.time({ year = year, month = month, day = 1, hour = 12 }))
  return t.wday  -- os.date already uses 1=Sun..7=Sat
end
```

- [ ] **Step 4: Run tests — expect all PASS**

Run:

    bash tests/run_tests.sh

Expected: `21 passed, 0 failed`.

- [ ] **Step 5: Commit**

Run:

    git add tests/test_calendar_model.lua 365Calendar.lrplugin/CalendarModel.lua
    git commit -m "feat(model): add firstWeekdayOfMonth for grid alignment"

---

## Task 12: `CollectionReader.lua`

Thin wrapper over the Lightroom catalog APIs. Not unit-testable without
Lightroom; keep deliberately small so the surface area for bugs stays tiny.

**Files:**
- Create: `365Calendar.lrplugin/CollectionReader.lua`

- [ ] **Step 1: Write the module**

```lua
-- CollectionReader: loads photo data from a Lightroom collection.
-- Isolates LR catalog I/O so the rest of the plugin can stay pure or stubbed.

local LrApplication = import "LrApplication"

local M = {}

-- Returns an array of regular (non-smart) LrCollection objects, recursively
-- walked from the active catalog's root. Smart collections are excluded —
-- see design spec, "Out of scope".
function M.listRegularCollections()
  local catalog = LrApplication.activeCatalog()
  local result = {}

  local function walk(children)
    for _, c in ipairs(children) do
      if c:type() == "LrCollection" and not c:isSmartCollection() then
        table.insert(result, c)
      end
      if c:type() == "LrCollectionSet" then
        walk(c:getChildCollections())
        walk(c:getChildCollectionSets())
      end
    end
  end

  walk(catalog:getChildCollections())
  walk(catalog:getChildCollectionSets())
  return result
end

-- Returns a human-readable path-prefixed name like "Trips/2026/Iceland" for
-- disambiguation in the picker.
function M.qualifiedName(collection)
  local parts = { collection:getName() }
  local parent = collection:getParent()
  while parent do
    table.insert(parts, 1, parent:getName())
    parent = parent:getParent()
  end
  return table.concat(parts, "/")
end

-- Returns the array of LrPhoto objects in the given collection.
function M.loadPhotos(collection)
  return collection:getPhotos()
end

return M
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CollectionReader.lua
    git commit -m "feat(plugin): add CollectionReader for catalog access"

---

## Task 13: `CalendarView` — cell renderers

Begin `CalendarView.lua` with the three cell builders (present, missing,
blank). These are pure LrView-table-builders; they do not call the LR API,
only the `LrView` factory.

**Files:**
- Create: `365Calendar.lrplugin/CalendarView.lua`

- [ ] **Step 1: Write the initial module with cell renderers**

```lua
-- CalendarView: builds the LrView tree for the calendar dialog.
-- All functions are pure with respect to their inputs — they return view
-- descriptors, never calling LR APIs directly.

local LrView  = import "LrView"
local LrColor = import "LrColor"

local M = {}

local CELL_SIZE = 80

local COLOR_MISSING_BG  = LrColor(0.95, 0.85, 0.85)
local COLOR_MISSING_FG  = LrColor(0.55, 0.25, 0.25)
local COLOR_OVERLAY_FG  = LrColor(1, 1, 1)
local COLOR_OVERLAY_BG  = LrColor(0.15, 0.15, 0.15)  -- opaque dark; LrColor alpha support is unreliable

-- A present-day cell: catalog photo thumbnail with overlaid day number and
-- "+N" badge (visible only when extras > 0).
function M._presentCell(f, cell)
  return f:place {
    width = CELL_SIZE, height = CELL_SIZE,

    f:catalog_photo {
      photo = cell.primary,
      width = CELL_SIZE, height = CELL_SIZE,
    },

    f:view {
      background_color = COLOR_OVERLAY_BG,
      place_horizontal = 0,
      place_vertical = 0,
      f:static_text {
        title = tostring(cell.day),
        text_color = COLOR_OVERLAY_FG,
        font = "<system/small/bold>",
      },
    },

    f:view {
      background_color = COLOR_OVERLAY_BG,
      place_horizontal = 1,
      place_vertical = 0,
      visible = cell.extras > 0,
      f:static_text {
        title = "+" .. tostring(cell.extras),
        text_color = COLOR_OVERLAY_FG,
        font = "<system/small>",
      },
    },
  }
end

-- A missing-day cell: soft-red filled box with centered day number.
function M._missingCell(f, cell)
  return f:view {
    width = CELL_SIZE, height = CELL_SIZE,
    background_color = COLOR_MISSING_BG,
    f:static_text {
      title = tostring(cell.day),
      text_color = COLOR_MISSING_FG,
      place_horizontal = 0.5,
      place_vertical = 0.5,
    },
  }
end

-- A blank cell: used for leading/trailing spacer slots to align the grid.
function M._blankCell(f)
  return f:view {
    width = CELL_SIZE, height = CELL_SIZE,
  }
end

return M
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CalendarView.lua
    git commit -m "feat(view): add present/missing/blank cell renderers"

---

## Task 14: `CalendarView` — weekday header row

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

- [ ] **Step 1: Add the weekday header builder**

Insert into `365Calendar.lrplugin/CalendarView.lua` **above** the `return M`
line:

```lua
local WEEKDAY_LABELS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

function M._weekdayHeader(f)
  local row = f:row { spacing = 4 }
  for _, label in ipairs(WEEKDAY_LABELS) do
    table.insert(row, f:static_text {
      title = label,
      width = CELL_SIZE,
      alignment = "center",
    })
  end
  return row
end
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CalendarView.lua
    git commit -m "feat(view): add Sunday-start weekday header row"

---

## Task 15: `CalendarView` — month grid body

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

- [ ] **Step 1: Add the grid builder**

Insert into `365Calendar.lrplugin/CalendarView.lua` above `return M`:

```lua
-- Builds the month grid: up to 6 rows of 7 cells each. Leading blanks
-- account for the weekday of the 1st; trailing blanks pad the final row so
-- the grid edge stays rectangular.
function M._grid(f, cells, firstWeekday)
  local column = f:column { spacing = 4 }

  local row = f:row { spacing = 4 }
  for _ = 1, (firstWeekday - 1) do
    table.insert(row, M._blankCell(f))
  end
  local inRow = firstWeekday - 1

  for _, cell in ipairs(cells) do
    local view
    if cell.primary then
      view = M._presentCell(f, cell)
    else
      view = M._missingCell(f, cell)
    end
    table.insert(row, view)
    inRow = inRow + 1
    if inRow == 7 then
      table.insert(column, row)
      row = f:row { spacing = 4 }
      inRow = 0
    end
  end

  -- Trailing blanks + flush partial row.
  if inRow > 0 then
    for _ = inRow + 1, 7 do
      table.insert(row, M._blankCell(f))
    end
    table.insert(column, row)
  end

  return column
end
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CalendarView.lua
    git commit -m "feat(view): compose month grid from cells and first weekday"

---

## Task 16: `CalendarView` — navigation bar and top bar

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

- [ ] **Step 1: Add the top bar and nav bar builders**

Insert into `365Calendar.lrplugin/CalendarView.lua` above `return M`:

```lua
local MONTH_NAMES = {
  "January", "February", "March", "April", "May", "June",
  "July", "August", "September", "October", "November", "December",
}

-- Top bar: collection picker + refresh button.
-- `state.collections` is an array of { title, value } entries;
-- `state.collectionValue` is the currently-selected value.
function M._topBar(f, state, properties)
  return f:row {
    spacing = 8,
    f:static_text { title = "Collection:" },
    f:popup_menu {
      items = state.collections,
      value = LrView.bind { key = "collectionValue", object = properties },
      width_in_chars = 30,
    },
    f:push_button {
      title = "Refresh",
      action = function() properties.action = "refresh" end,
    },
  }
end

-- Nav bar: prev button, centered month/year label, next button.
function M._navBar(f, state, properties)
  return f:row {
    f:push_button {
      title = "<",
      action = function() properties.action = "prev" end,
    },
    f:spacer { fill_horizontal = 1 },
    f:static_text {
      title = MONTH_NAMES[state.month] .. " " .. tostring(state.year),
      font = "<system/bold>",
      alignment = "center",
      width_in_chars = 20,
    },
    f:spacer { fill_horizontal = 1 },
    f:push_button {
      title = ">",
      action = function() properties.action = "next" end,
    },
  }
end
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CalendarView.lua
    git commit -m "feat(view): add top bar and nav bar builders"

---

## Task 17: `CalendarView.build` — compose everything

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

- [ ] **Step 1: Add the top-level `build` function**

Insert into `365Calendar.lrplugin/CalendarView.lua` above `return M`:

```lua
-- Builds the complete dialog contents for a single month render.
--
-- `state` shape: {
--   collections     = { { title = string, value = LrCollection }, ... },
--   collectionValue = <LrCollection currently selected>,
--   year            = integer,
--   month           = 1..12,
--   cells           = array of { day, primary, extras } for this month,
--   firstWeekday    = 1..7 (1 = Sunday),
-- }
--
-- `properties` is an LrBinding property table; buttons mutate `properties.action`
-- to signal the navigation loop which transition to take.
function M.build(state, properties)
  local f = LrView.osFactory()
  return f:column {
    spacing = 10,
    bind_to_object = properties,

    M._topBar(f, state, properties),
    M._navBar(f, state, properties),
    f:separator { fill_horizontal = 1 },
    M._weekdayHeader(f),
    f:scrolled_view {
      width = (CELL_SIZE + 4) * 7 + 20,
      height = (CELL_SIZE + 4) * 6 + 20,
      M._grid(f, state.cells, state.firstWeekday),
    },
  }
end
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/CalendarView.lua
    git commit -m "feat(view): add top-level CalendarView.build"

---

## Task 18: `ShowCalendarDialog.lua` — entry point and navigation loop

**Files:**
- Create: `365Calendar.lrplugin/ShowCalendarDialog.lua`

- [ ] **Step 1: Write the module**

```lua
-- ShowCalendarDialog: entry point invoked from the Library menu.
-- Owns the re-present-dialog-per-navigation loop.

local LrTasks            = import "LrTasks"
local LrDialogs          = import "LrDialogs"
local LrBinding          = import "LrBinding"
local LrFunctionContext  = import "LrFunctionContext"

local CalendarModel    = require("CalendarModel")
local CollectionReader = require("CollectionReader")
local CalendarView     = require("CalendarView")

local function currentYearMonth()
  local t = os.date("*t")
  return t.year, t.month
end

local function buildState(collectionValue, collectionsList, year, month, model)
  return {
    collections     = collectionsList,
    collectionValue = collectionValue,
    year            = year,
    month           = month,
    cells           = model and model:cellsForMonth(year, month) or {},
    firstWeekday    = CalendarModel.firstWeekdayOfMonth(year, month),
  }
end

local function run()
  LrFunctionContext.callWithContext("365Calendar.dialog", function(context)
    local collections = CollectionReader.listRegularCollections()
    if #collections == 0 then
      LrDialogs.message("365 Calendar", "No regular collections found in this catalog.", "info")
      return
    end

    local collectionsList = {}
    for _, c in ipairs(collections) do
      table.insert(collectionsList, {
        title = CollectionReader.qualifiedName(c),
        value = c,
      })
    end

    local currentCollection = collections[1]
    local year, month = currentYearMonth()
    local model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))

    while true do
      local properties = LrBinding.makePropertyTable(context)
      properties.collectionValue = currentCollection
      properties.action = nil

      local state = buildState(currentCollection, collectionsList, year, month, model)

      local result = LrDialogs.presentModalDialog {
        title  = "365 Project Calendar",
        contents = CalendarView.build(state, properties),
        actionVerb = "Close",
        cancelVerb = "< exclude >",  -- hide default Cancel
      }

      -- Handle collection change before acting on button presses.
      if properties.collectionValue ~= currentCollection then
        currentCollection = properties.collectionValue
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      end

      local action = properties.action
      if action == "prev" then
        year, month = CalendarModel.rollMonth(year, month, -1)
      elseif action == "next" then
        year, month = CalendarModel.rollMonth(year, month, 1)
      elseif action == "refresh" then
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      else
        break  -- user clicked Close or dismissed
      end
    end
  end)
end

LrTasks.startAsyncTask(run)
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/ShowCalendarDialog.lua
    git commit -m "feat(plugin): add entry point with navigation loop"

---

## Task 19: Localized strings

**Files:**
- Create: `365Calendar.lrplugin/strings/TranslatedStrings.txt`

- [ ] **Step 1: Write the strings file**

```
"$$$/365Calendar/PluginName=365 Project Calendar"
"$$$/365Calendar/MenuItem=Show 365 Calendar..."
```

- [ ] **Step 2: Commit**

Run:

    git add 365Calendar.lrplugin/strings/TranslatedStrings.txt
    git commit -m "chore(i18n): add English TranslatedStrings"

---

## Task 20: Install and smoke test

Now that every file is in place, verify the plugin loads and the dialog works.
Document the outcome.

**Files:**
- Modify (only if smoke-test reveals bugs): any plugin files

- [ ] **Step 1: Symlink the plugin into Lightroom's modules folder**

Run:

    ln -s "$PWD/365Calendar.lrplugin" \
      "$HOME/Library/Application Support/Adobe/Lightroom/Modules/365Calendar.lrplugin"

- [ ] **Step 2: Launch Lightroom Classic and verify plugin appears**

Open Lightroom Classic. Go to `File > Plug-in Manager…`. Verify:
- "365 Project Calendar" appears in the plugin list.
- Status shows "Installed and running" (or equivalent green indicator).
- No error messages in the plugin's status area.

- [ ] **Step 3: Open the calendar and verify core flow**

`Library > Plug-in Extras > Show 365 Calendar…`.

Check each of the following:

1. Dialog opens without error.
2. Collection popup lists regular (non-smart) collections only.
3. Current month displays (default: month of today's date).
4. Days with photos show thumbnails; days without show soft-red tinted cells.
5. Multi-photo days show a `+N` badge in the corner.
6. Clicking `<` moves back one month; `>` moves forward. Year rolls at
   December→next and January→prev.
7. Refresh button re-reads the currently selected collection.
8. Switching the collection popup rebuilds the view with the new collection's
   photos.
9. Close button dismisses the dialog.

- [ ] **Step 4: Address any LrView verification points from the spec**

The spec flagged three open LrView API questions. Resolve during smoke test:

1. `static_text` + `background_color`: if the overlays render without visible
   pill backgrounds, you may need to restructure: the present-cell code
   already wraps the text in `f:view { background_color = ... }`, which is
   the expected working path. If still broken, consult SDK docs for
   alternative layout approaches.
2. `f:place` with `place_horizontal`/`place_vertical`: if corner-pinning
   doesn't work, fall back to absolute `margin_left`/`margin_top` offsets on
   the overlay children.
3. `LrDialogs.stopModalWithResult` vs observable properties: the plan uses
   `properties.action` mutated inside button callbacks, which is the
   observable-property approach. If buttons don't close the dialog,
   switch to `LrDialogs.stopModalWithResult(properties, "prev")` inside each
   button's `action` callback.

- [ ] **Step 5: Commit any fixes from smoke testing**

If the smoke test surfaced needed fixes, commit them with focused messages:

    git add <files>
    git commit -m "fix(view): <specific correction discovered in smoke test>"

- [ ] **Step 6: Final verification commit**

Add a note to `CLAUDE.md` under a new "Verified behavior" section capturing
what currently works and any known issues to revisit:

```markdown
## Verified behavior (as of <YYYY-MM-DD>)

- Plugin loads into Lightroom Classic <version>.
- Calendar dialog opens via Library > Plug-in Extras.
- Month navigation, refresh, and collection switching all work.
- Multi-photo days show +N badges.
- Known limitations: <any discovered>
```

Commit:

    git add CLAUDE.md
    git commit -m "docs: record verified behavior from initial smoke test"

---

## Out of scope for this plan (do not implement)

Per the spec's "Out of scope" section, this plan **does not** cover any of
the following. Do not scaffold or write code for them:

- Lightroom CC / Cloud plugin surface.
- Direct SQLite reading of `.lrcat`.
- Smart-collection rule evaluation.
- Quarter-view or year-view calendar layouts.
- Click interactions on calendar cells.
- Configurable week start (Sunday hard-coded for v1).
- iOS or macOS companion apps.
