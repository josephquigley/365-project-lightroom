# Missing-Days View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Missing" view mode to the 365 Calendar dialog that lists dates without photos between the collection's earliest photo and today. Both modes display a shared `Day N` project-day counter in the top bar.

**Architecture:** Two new pure-Lua methods on `CalendarModel` (`projectDayOf`, `missingDays`). A segmented toggle in the shared top bar swaps the content region between the existing month grid and a new flat "missing" grid. The dialog loop treats the toggle like the existing nav buttons — buttons close the modal with a sentinel result (`"view:calendar"` / `"view:missing"`) and the loop re-presents in the new mode.

**Tech Stack:** Lua 5.1, Lightroom SDK (`LrView`, `LrColor`, `LrDialogs`, `LrBinding`), plain-Lua unit tests via `bash tests/run_tests.sh`.

**Design spec:** `docs/superpowers/specs/2026-04-22-missing-days-view-design.md`.

---

## File Structure

- **Modify** `365Calendar.lrplugin/CalendarModel.lua` — add `projectDayOf(today)` and `missingDays(today)` methods. All new logic is pure Lua.
- **Modify** `tests/test_calendar_model.lua` — append test cases for the two new methods, using the existing `test`, `assert_equal`, `assert_nil`, `stubPhoto`, `cocoaAt` helpers.
- **Modify** `365Calendar.lrplugin/CalendarView.lua` — augment the top bar with a segmented toggle + `Day N` label; add `_missingProjectCell`, `_missingGrid`, and `_missingContent` helpers; branch `M.build` on `state.view`.
- **Modify** `365Calendar.lrplugin/ShowCalendarDialog.lua` — track a loop-local `viewMode`, pass it + computed `today` / `todayProjectDay` / `missingDays` through `buildState`, extend the result-handler switch.

No files are created. No files are deleted.

---

## Conventions shared by every task

- Lua 5.1 only — no 5.2+ syntax.
- 2-space indentation; `snake_case` locals; module table returned at EOF.
- `CalendarModel.lua` changes are TDD — one behavior per commit (red → minimal → green → commit), per `CLAUDE.md`.
- UI changes cannot be unit-tested. The final task manually smoke-tests in Lightroom Classic and records the steps in the commit message.
- Run the test suite with:
  ```bash
  bash tests/run_tests.sh
  ```
  Expected output on success ends with `N passed, 0 failed`.

---

## Task 1: Model — `projectDayOf(today)`

**Files:**
- Test: `tests/test_calendar_model.lua` (append at end, before the `print(...)` summary)
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

Follow the TDD discipline: write one test, watch it fail, add just enough implementation to pass, commit, repeat.

### Step 1.1: Append a "projectDayOf" section header comment and the first failing test

- [ ] **Write the failing test**

Append to `tests/test_calendar_model.lua`, immediately above the `print(...)` line at the bottom:

```lua
-- ---------------------------------------------------------------
-- projectDayOf(today): inclusive day count since the earliest photo
-- ---------------------------------------------------------------

test("projectDayOf: nil when the model has no photos", function()
  local m = CalendarModel.new({})
  assert_nil(m:projectDayOf({ year = 2026, month = 4, day = 22 }))
end)
```

- [ ] **Run test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: the final line reads something like `X passed, 1 failed`, and the new test FAILs (likely "attempt to call method 'projectDayOf'").

- [ ] **Add the minimal implementation**

In `365Calendar.lrplugin/CalendarModel.lua`, add this method definition after the existing `Model:_binFor` method (i.e., in the `Model` metatable block, before `function M.new(photos)`):

```lua
function Model:projectDayOf(today)
  if not self._start then return nil end
  return nil  -- will be fleshed out in the next step
end
```

Wait — returning `nil` here will pass the first test (the "no photos" case both with and without the guard), but the following tests will fail. That's correct TDD: we drive the implementation out one behavior at a time.

- [ ] **Run test to verify it passes**

Run: `bash tests/run_tests.sh`
Expected: the just-added test PASSes. Full summary should show all previous tests still passing, and the new one passing.

- [ ] **Commit**

```bash
git add 365Calendar.lrplugin/CalendarModel.lua tests/test_calendar_model.lua
git commit -m "test(model): projectDayOf returns nil for empty model"
```

### Step 1.2: Returns 1 when today equals `_start`

- [ ] **Write the failing test**

Append to `tests/test_calendar_model.lua` before `print(...)`:

```lua
test("projectDayOf: 1 when today equals the earliest-photo date", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 15 }), 1)
end)
```

- [ ] **Run test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: `projectDayOf: 1 when today equals ...` FAILs (returns `nil`, expected `1`).

- [ ] **Implement**

There is already a file-local `daysBetween(a, b)` helper in `CalendarModel.lua` that accepts two `{year, month, day}` tables and returns whole days between them. Use it. Replace the `projectDayOf` body with:

```lua
function Model:projectDayOf(today)
  if not self._start then return nil end
  return daysBetween(self._start, today) + 1
end
```

- [ ] **Run test to verify it passes**

Run: `bash tests/run_tests.sh`
Expected: the new test PASSes.

- [ ] **Commit**

```bash
git add 365Calendar.lrplugin/CalendarModel.lua tests/test_calendar_model.lua
git commit -m "feat(model): projectDayOf returns inclusive day count"
```

### Step 1.3: N+1 for N days after `_start`; negative for a future `_start`; month-boundary correctness

These three behaviors share a single implementation (the one from Step 1.2 already covers them). We add their tests to pin the contract. Commit them together.

- [ ] **Write three failing tests** (append all three to `tests/test_calendar_model.lua` before `print(...)`)

```lua
test("projectDayOf: returns N+1 when today is N days after the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  -- 5 days after April 15 is April 20 -> Day 6
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 20 }), 6)
end)

test("projectDayOf: spans month boundaries", function()
  -- Earliest Jan 30 2026; today Feb 2 2026 -> 4 days (30, 31, 1, 2) inclusive -> Day 4
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 30, 10) })
  local m = CalendarModel.new({ p })
  assert_equal(m:projectDayOf({ year = 2026, month = 2, day = 2 }), 4)
end)

test("projectDayOf: negative when today precedes the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  -- April 12 is 3 days before April 15; 1 - 3 = -2
  assert_equal(m:projectDayOf({ year = 2026, month = 4, day = 12 }), -2)
end)
```

- [ ] **Run test to verify they pass**

The Step 1.2 implementation already satisfies all three. Run: `bash tests/run_tests.sh`
Expected: all three new tests PASS without any implementation change. (If any fail, `daysBetween` likely returned a sign-flipped value — double-check `CalendarModel.lua` and adjust as needed before committing.)

- [ ] **Commit**

```bash
git add tests/test_calendar_model.lua
git commit -m "test(model): pin projectDayOf behavior across offset, boundary, and negative cases"
```

---

## Task 2: Model — `missingDays(today)`

**Files:**
- Test: `tests/test_calendar_model.lua` (append at end)
- Modify: `365Calendar.lrplugin/CalendarModel.lua`

### Step 2.1: Empty model returns `{}`

- [ ] **Write the failing test**

Append to `tests/test_calendar_model.lua` before `print(...)`:

```lua
-- ---------------------------------------------------------------
-- missingDays(today): ordered list of dates without a photo
-- ---------------------------------------------------------------

test("missingDays: empty model returns empty list", function()
  local m = CalendarModel.new({})
  local result = m:missingDays({ year = 2026, month = 4, day = 22 })
  assert_equal(type(result), "table")
  assert_equal(#result, 0)
end)
```

- [ ] **Run test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL with "attempt to call method 'missingDays'".

- [ ] **Implement**

Add to `CalendarModel.lua`, directly after the `Model:projectDayOf` method:

```lua
function Model:missingDays(today)
  if not self._start then return {} end
  return {}
end
```

This is a deliberate stub — the next step drives the real behavior.

- [ ] **Run test to verify it passes**

Run: `bash tests/run_tests.sh`
Expected: test PASSes.

- [ ] **Commit**

```bash
git add 365Calendar.lrplugin/CalendarModel.lua tests/test_calendar_model.lua
git commit -m "test(model): missingDays returns empty list for empty model"
```

### Step 2.2: Returns `{}` when today precedes `_start`

- [ ] **Write the failing test**

```lua
test("missingDays: empty list when today precedes the earliest photo", function()
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local m = CalendarModel.new({ p })
  local result = m:missingDays({ year = 2026, month = 4, day = 10 })
  assert_equal(#result, 0)
end)
```

- [ ] **Run test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — the stub returned `{}` only for empty models, not for a backwards range. Actually the current stub returns `{}` in all paths *except* when `_start` is nil. Wait — it returns `{}` unconditionally. So this test will PASS against the stub. That is fine — skip to the commit below. (If it unexpectedly fails, double-check nothing was changed in Step 2.1.)

Actually this test passes trivially. Treat it as a pinning test and commit alongside Step 2.3 rather than individually — but the plan keeps it here so the contract is recorded.

- [ ] **Commit the pinning test**

```bash
git add tests/test_calendar_model.lua
git commit -m "test(model): missingDays returns empty list when today precedes start"
```

### Step 2.3: One entry for a single one-day gap

- [ ] **Write the failing test**

```lua
test("missingDays: one entry for a single-day gap", function()
  -- Photo on day 1 and day 3; day 2 is the single missing day.
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local p3 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 17, 10) })
  local m = CalendarModel.new({ p1, p3 })
  local result = m:missingDays({ year = 2026, month = 4, day = 17 })
  assert_equal(#result, 1)
  assert_equal(result[1].year, 2026)
  assert_equal(result[1].month, 4)
  assert_equal(result[1].day, 16)
  assert_equal(result[1].project_day, 2)
end)
```

- [ ] **Run test to verify it fails**

Run: `bash tests/run_tests.sh`
Expected: FAIL — the stub returns `{}`.

- [ ] **Implement**

Replace the `Model:missingDays` stub with a walk from `_start` to `today`:

```lua
function Model:missingDays(today)
  if not self._start then return {} end
  local span = daysBetween(self._start, today)
  if span < 0 then return {} end

  local out = {}
  for offset = 0, span do
    local t = os.date("*t", os.time({
      year = self._start.year,
      month = self._start.month,
      day = self._start.day + offset,
      hour = 12,
    }))
    local key = string.format("%04d-%02d-%02d", t.year, t.month, t.day)
    if not self._bins[key] then
      out[#out + 1] = {
        year        = t.year,
        month       = t.month,
        day         = t.day,
        project_day = offset + 1,
      }
    end
  end
  return out
end
```

Notes for the implementer:

- `self._bins` is keyed by `string.format("%04d-%02d-%02d", y, m, d)` — matching the private `dayKey` helper at the top of the file. Keep the format string in sync; if you prefer, expose `dayKey` as a file-local upvalue and reuse it (small follow-up clean-up is OK if it reduces duplication, but don't change the format).
- Noon anchoring (`hour = 12`) sidesteps DST seams, matching the existing `daysBetween` helper.
- `daysBetween` already lives in the same file as a file-local. Use it rather than re-implementing date math.

- [ ] **Run test to verify it passes**

Run: `bash tests/run_tests.sh`
Expected: test PASSes.

- [ ] **Commit**

```bash
git add 365Calendar.lrplugin/CalendarModel.lua tests/test_calendar_model.lua
git commit -m "feat(model): missingDays emits one entry per gap"
```

### Step 2.4: Entries are ordered, `project_day` matches `projectDayOf`, skips present dates, month/leap boundary

One test per behavior, committed together since the Step 2.3 implementation already satisfies them.

- [ ] **Write the pinning tests**

```lua
test("missingDays: all days missing between two bookend photos", function()
  -- Photos on Apr 15 and Apr 19; days 16, 17, 18 are missing (3 entries).
  local p_start = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local p_end   = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 19, 10) })
  local m = CalendarModel.new({ p_start, p_end })
  local result = m:missingDays({ year = 2026, month = 4, day = 19 })
  assert_equal(#result, 3)
  assert_equal(result[1].day, 16)
  assert_equal(result[2].day, 17)
  assert_equal(result[3].day, 18)
  assert_equal(result[1].project_day, 2)
  assert_equal(result[3].project_day, 4)
end)

test("missingDays: no entries emitted for days that have photos", function()
  local p1 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 15, 10) })
  local p2 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 16, 10) })
  local p3 = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 4, 17, 10) })
  local m = CalendarModel.new({ p1, p2, p3 })
  local result = m:missingDays({ year = 2026, month = 4, day = 17 })
  assert_equal(#result, 0)
end)

test("missingDays: spans a month boundary", function()
  -- Earliest Jan 30 2026; today Feb 2 2026; no other photos.
  -- Missing: Jan 31, Feb 1, Feb 2 (3 entries).
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2026, 1, 30, 10) })
  local m = CalendarModel.new({ p })
  local result = m:missingDays({ year = 2026, month = 2, day = 2 })
  assert_equal(#result, 3)
  assert_equal(result[1].month, 1); assert_equal(result[1].day, 31)
  assert_equal(result[2].month, 2); assert_equal(result[2].day, 1)
  assert_equal(result[3].month, 2); assert_equal(result[3].day, 2)
end)

test("missingDays: handles leap February", function()
  -- Earliest Feb 28 2024; today Mar 1 2024; no other photos.
  -- Missing: Feb 29, Mar 1 (2 entries) -- leap day must be present in the walk.
  local p = stubPhoto({ dateTimeOriginal = cocoaAt(2024, 2, 28, 10) })
  local m = CalendarModel.new({ p })
  local result = m:missingDays({ year = 2024, month = 3, day = 1 })
  assert_equal(#result, 2)
  assert_equal(result[1].month, 2); assert_equal(result[1].day, 29)
  assert_equal(result[2].month, 3); assert_equal(result[2].day, 1)
end)
```

- [ ] **Run tests to verify they pass**

Run: `bash tests/run_tests.sh`
Expected: all four new tests PASS, the overall summary shows 0 failed.

- [ ] **Commit**

```bash
git add tests/test_calendar_model.lua
git commit -m "test(model): pin missingDays ordering, month boundary, leap day"
```

---

## Task 3: View — top bar with segmented toggle + `Day N`

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

This is UI code and is not unit-tested. After the code edit, do the project-standard manual verification in Lightroom before committing.

### Step 3.1: Replace `_topBar` with a version that has the toggle and Day N label

- [ ] **Edit `_topBar`**

In `365Calendar.lrplugin/CalendarView.lua`, replace the entire `M._topBar` function (lines ~169-187 in the current file) with:

```lua
-- Top bar: collection picker, view-mode toggle, refresh button, and Day N
-- readout. The toggle is two push_buttons; the one matching the current
-- view is disabled to act as a selected state. Clicking a button closes
-- the modal with a "view:<mode>" result so the dialog loop re-presents
-- in the new mode.
--
-- `state.view` is "calendar" or "missing".
-- `state.todayProjectDay` is a number, or nil when the collection is empty.
function M._topBar(f, state, properties, close_with)
  local dayLabel = state.todayProjectDay
    and ("Day " .. tostring(state.todayProjectDay))
    or "Day —"

  return f:row {
    spacing = 8,
    f:static_text { title = "Collection:" },
    f:popup_menu {
      items = state.collections,
      value = LrView.bind { key = "collectionValue", object = properties },
      width_in_chars = 30,
    },
    f:push_button {
      title = "Calendar",
      enabled = state.view ~= "calendar",
      action = function() close_with("view:calendar") end,
    },
    f:push_button {
      title = "Missing",
      enabled = state.view ~= "missing",
      action = function() close_with("view:missing") end,
    },
    f:push_button {
      title = "Refresh",
      action = function() close_with("refresh") end,
    },
    f:spacer { fill_horizontal = 1 },
    f:static_text {
      title = dayLabel,
      font = "<system/bold>",
    },
  }
end
```

The rest of `CalendarView.lua` is untouched in this step — `_navBar`, cell builders, and `M.build` stay as they are for now.

- [ ] **Verify the tests still pass**

Run: `bash tests/run_tests.sh`
Expected: all tests PASS. (UI changes shouldn't affect the model tests, but this confirms the file still loads cleanly.)

- [ ] **Hold commit until Task 5 so the manual smoke test exercises the wired-up change**

The top bar now references `state.view` and `state.todayProjectDay`, which the dialog doesn't supply yet. Don't commit yet; the code will render incorrectly (disabled check and Day label both falsy) until Task 5. Tasks 3–5 form a single coherent change that is verified together.

---

## Task 4: View — missing-mode content region

**Files:**
- Modify: `365Calendar.lrplugin/CalendarView.lua`

### Step 4.1: Add the `_missingProjectCell` helper

- [ ] **Add the helper**

In `CalendarView.lua`, insert this new function immediately after the existing `M._missingCell` function:

```lua
-- A missing-cell used in the Missing view. Same soft-red box as
-- `_missingCell`, but with a "Day N" label below so the photographer can
-- see which project day each missing entry corresponds to.
-- `entry` shape: { year, month, day, project_day }.
function M._missingProjectCell(f, entry)
  return f:column {
    spacing = 2,
    f:view {
      width = CELL_SIZE, height = CELL_SIZE,
      background_color = COLOR_MISSING_BG,
      f:static_text {
        title = tostring(entry.day),
        text_color = COLOR_MISSING_FG,
        place_horizontal = 0.5,
        place_vertical = 0.5,
      },
    },
    f:static_text {
      title = "Day " .. tostring(entry.project_day),
      width = CELL_SIZE,
      alignment = "center",
      font = "<system/small>",
    },
  }
end
```

### Step 4.2: Add the `_missingGrid` helper

- [ ] **Add the helper**

Add directly after `M._missingProjectCell`:

```lua
-- A flat 7-across grid of missing-entry cells. No leading blanks, no
-- weekday header, no month dividers -- cells are packed by list index in
-- the order they appear in `entries`.
-- Children are built into args tables before the row/column is constructed;
-- post-hoc table.insert on a completed LrView row/column is silently dropped.
function M._missingGrid(f, entries)
  local columnArgs = { spacing = 4 }
  local rowArgs = { spacing = 4 }
  local inRow = 0

  for _, entry in ipairs(entries) do
    rowArgs[#rowArgs + 1] = M._missingProjectCell(f, entry)
    inRow = inRow + 1
    if inRow == 7 then
      columnArgs[#columnArgs + 1] = f:row(rowArgs)
      rowArgs = { spacing = 4 }
      inRow = 0
    end
  end

  if inRow > 0 then
    for _ = inRow + 1, 7 do
      rowArgs[#rowArgs + 1] = M._blankCell(f)
    end
    columnArgs[#columnArgs + 1] = f:row(rowArgs)
  end

  return f:column(columnArgs)
end
```

### Step 4.3: Add the `_missingContent` helper

- [ ] **Add the helper**

Add directly after `M._missingGrid`:

```lua
-- Content region for the Missing view: a one-line summary plus the grid
-- (or a full-width message, when the edge cases apply).
-- Shapes:
--   empty collection        -> "No photos in this collection."
--   non-empty, zero missing -> "You're caught up -- no missing days."
--   otherwise               -> "N missing" line, then grid
function M._missingContent(f, state)
  if not state.todayProjectDay then
    return f:column {
      spacing = 8,
      f:static_text { title = "No photos in this collection." },
    }
  end
  if #state.missingDays == 0 then
    return f:column {
      spacing = 8,
      f:static_text { title = "You're caught up — no missing days." },
    }
  end
  return f:column {
    spacing = 8,
    f:static_text {
      title = tostring(#state.missingDays) .. " missing",
      font = "<system/bold>",
    },
    M._missingGrid(f, state.missingDays),
  }
end
```

### Step 4.4: Branch `M.build` on `state.view`

- [ ] **Replace the body of `M.build`**

Still in `CalendarView.lua`, replace the existing `M.build(state, properties)` function (the one that ends the file, before `return M`) with:

```lua
function M.build(state, properties)
  local f = LrView.osFactory()
  -- Forward-declare the root view so button callbacks can reference it.
  -- LrDialogs.stopModalWithResult needs a view that lives inside the
  -- currently-presented modal to walk up and find the dialog; the root view
  -- is the surest bet.
  local root
  local function close_with(result)
    LrDialogs.stopModalWithResult(root, result)
  end

  local children = {
    spacing = 10,
    bind_to_object = properties,

    M._topBar(f, state, properties, close_with),
  }

  if state.view == "missing" then
    children[#children + 1] = f:separator { fill_horizontal = 1 }
    children[#children + 1] = f:scrolled_view {
      width = (CELL_SIZE + 4) * 7 + 20,
      height = (CELL_SIZE + 28) * 6 + 20,
      M._missingContent(f, state),
    }
  else
    children[#children + 1] = M._navBar(f, state, properties, close_with)
    children[#children + 1] = f:separator { fill_horizontal = 1 }
    children[#children + 1] = M._weekdayHeader(f)
    children[#children + 1] = f:scrolled_view {
      -- Cells include a "Day N" label beneath the thumbnail, so the
      -- vertical footprint grows by ~24px per row (label + spacing).
      width = (CELL_SIZE + 4) * 7 + 20,
      height = (CELL_SIZE + 28) * 6 + 20,
      M._grid(f, state.cells, state.firstWeekday),
    }
  end

  root = f:column(children)
  return root
end
```

Key points:

- The `children` args table is built before the `f:column` is constructed, because `LrView` finalizes children at construction time (post-hoc `table.insert` on a completed view is silently dropped — documented gotcha in `CLAUDE.md`).
- The top bar is identical across both modes.
- In missing mode, `state.cells` and `state.firstWeekday` are not read, so the dialog doesn't need to compute them when `view == "missing"`.

- [ ] **Verify the model tests still pass**

Run: `bash tests/run_tests.sh`
Expected: all tests PASS. (UI edits shouldn't affect models, but this confirms the file still loads.)

- [ ] **Still hold the commit until Task 5.** The UI now expects dialog-provided state keys (`state.view`, `state.todayProjectDay`, `state.missingDays`) that aren't set yet.

---

## Task 5: Dialog wiring

**Files:**
- Modify: `365Calendar.lrplugin/ShowCalendarDialog.lua`

### Step 5.1: Rewrite `buildState` and extend the loop

- [ ] **Edit `ShowCalendarDialog.lua`**

Replace the entire contents of `ShowCalendarDialog.lua` with:

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

local function currentDate()
  local t = os.date("*t")
  return { year = t.year, month = t.month, day = t.day }
end

local function buildState(collectionValue, collectionsList, view, year, month, model)
  local today = currentDate()
  local now   = os.date("*t")
  local state = {
    collections      = collectionsList,
    collectionValue  = collectionValue,
    view             = view,
    today            = today,
    todayProjectDay  = model and model:projectDayOf(today) or nil,
    todayYear        = now.year,
    todayMonth       = now.month,
  }
  if view == "missing" then
    state.missingDays = model and model:missingDays(today) or {}
  else
    state.year         = year
    state.month        = month
    state.cells        = model and model:cellsForMonth(year, month) or {}
    state.firstWeekday = CalendarModel.firstWeekdayOfMonth(year, month)
  end
  return state
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

    local currentCollection = CollectionReader.activeRegularCollection() or collections[1]
    local year, month = currentYearMonth()
    local viewMode = "calendar"
    local model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))

    while true do
      local properties = LrBinding.makePropertyTable(context)
      properties.collectionValue = currentCollection

      local state = buildState(currentCollection, collectionsList, viewMode, year, month, model)

      local result = LrDialogs.presentModalDialog {
        title      = "365 Project Calendar",
        contents   = CalendarView.build(state, properties),
        actionVerb = "Close",
        cancelVerb = "< exclude >",  -- hide default Cancel
        save_frame = "365Calendar.mainDialog",
      }

      -- Collection popup may have changed without closing the dialog via a button.
      if properties.collectionValue ~= currentCollection then
        currentCollection = properties.collectionValue
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      end

      if result == "prev" then
        year, month = CalendarModel.rollMonth(year, month, -1)
      elseif result == "next" then
        year, month = CalendarModel.rollMonth(year, month, 1)
      elseif result == "refresh" then
        model = CalendarModel.new(CollectionReader.loadPhotos(currentCollection))
      elseif result == "view:calendar" then
        viewMode = "calendar"
      elseif result == "view:missing" then
        viewMode = "missing"
      else
        break  -- user clicked Close or dismissed
      end
    end
  end)
end

LrTasks.startAsyncTask(run)
```

Notes:

- `buildState` only computes `cells`/`firstWeekday` in calendar mode and only computes `missingDays` in missing mode, so we don't do work the current view will ignore.
- `state.todayYear`/`todayMonth` are kept so the existing `_navBar` "disable next at current month" logic keeps working unchanged.

- [ ] **Run the model tests**

Run: `bash tests/run_tests.sh`
Expected: all PASS. (`ShowCalendarDialog.lua` isn't loaded by the tests, but this guards against accidentally breaking the model file during editing.)

### Step 5.2: Manual smoke test in Lightroom Classic

Before committing, verify end-to-end. Since the smoke test is the only real verification for UI code (per `CLAUDE.md`), do this thoroughly.

- [ ] **Ensure the plugin is symlinked into Lightroom's modules folder** (if not already set up from earlier work):

  ```bash
  ln -sf "$PWD/365Calendar.lrplugin" \
    "$HOME/Library/Application Support/Adobe/Lightroom/Modules/365Calendar.lrplugin"
  ```

- [ ] **Open Lightroom Classic**. If it's already running, restart it so the plugin reloads from the edited files.

- [ ] **Open the plugin** via `Library > Plug-in Extras > Show 365 Calendar`.

- [ ] **Verify all six smoke points** and record the outcome:

  1. On a collection with photos: the top bar shows `Calendar` (disabled/selected) and `Missing` (enabled) buttons, plus `Day N` on the right where N matches the current project day. The month grid and nav bar render as before.
  2. Click `Missing`: the dialog re-presents — nav bar and weekday header are gone, missing-days grid renders with day-of-month in each soft-red cell and `Day N` beneath each. A `N missing` header sits above the grid.
  3. Click `Calendar`: the month grid returns; window position is preserved.
  4. Switch the collection via the dropdown while in Missing mode: the list refreshes against the new collection's photos; `Day N` updates.
  5. Open the plugin on an empty (no-photo) collection: `Day —` in the top bar; switching to `Missing` shows the text `No photos in this collection.` with no grid.
  6. Open on a collection where every day from the first photo to today has a photo: `Missing` shows `You're caught up — no missing days.` with no grid.

- [ ] **Commit** (bundling the three-file UI/model-wiring change with the smoke-test notes in the message)

```bash
git add \
  365Calendar.lrplugin/CalendarView.lua \
  365Calendar.lrplugin/ShowCalendarDialog.lua

git commit -m "$(cat <<'EOF'
feat(plugin): add Missing view mode with Day N counter

Add a segmented Calendar/Missing toggle in the top bar, a shared "Day N"
readout using the inclusive day count since the collection's earliest
photo, and a flat missing-days grid that surfaces dates without a photo.

Smoke-tested in Lightroom Classic:
- Calendar mode renders unchanged; Day N reads correctly.
- Clicking Missing re-presents the dialog with the missing-days grid and
  "N missing" header; Calendar returns to the month grid with window
  position preserved.
- Switching collection while in Missing mode refreshes the list.
- Empty collection: Day — in top bar, "No photos in this collection."
  in Missing.
- Caught-up collection: "You're caught up — no missing days."
EOF
)"
```

---

## Self-Review Checklist (run after completing all tasks)

- [ ] All tests pass: `bash tests/run_tests.sh`
- [ ] Spec requirements covered:
  - (1) Segmented toggle in top bar — Task 3.
  - (2) `Day N` in both modes — Task 3 (label), Task 1 (`projectDayOf`), Task 5 (wiring).
  - (3) `N missing` in Missing view — Task 4 (`_missingContent`).
  - (4) Existing behaviors intact — Task 5 preserves `collectionValue`, `refresh`, `prev`/`next`, `todayYear`/`todayMonth`, and `save_frame`.
  - (5) No click handlers on cells — the cells in both modes are static.
- [ ] Edge cases: empty collection (Task 4 `_missingContent` early return + Task 3 `Day —`), future-first-photo (`projectDayOf` returns literal value; `missingDays` returns `{}`), caught-up (Task 4 `_missingContent` second early return).
- [ ] Commit log: one commit per model behavior; one commit for the UI/wiring bundle with the smoke-test notes in the message body.
