# Smart Collection Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow the 365 Calendar plugin to read photos from smart collections in addition to regular collections, with a `[smart]` marker in the dropdown label.

**Architecture:** Drop the smart-collection filter from `CollectionReader`, rename the two listing functions to reflect the new scope (`listCollections`, `activeCollection`), add a `displayLabel` helper that appends `[smart]` for smart collections, and update the one caller in `ShowCalendarDialog.lua` plus the two affected docs (`CLAUDE.md`, `README.md`).

**Tech Stack:** Lua 5.1, Lightroom SDK (`LrApplication`, `LrCollection`). No unit tests — `CollectionReader` is untestable without the SDK.

**Design spec:** `docs/superpowers/specs/2026-04-23-smart-collection-support-design.md`.

---

## File Structure

- **Modify** `365Calendar.lrplugin/CollectionReader.lua` — rename `listRegularCollections` → `listCollections`, rename `activeRegularCollection` → `activeCollection`, drop the `isSmartCollection` filter from both, add a new `displayLabel(collection)` function.
- **Modify** `365Calendar.lrplugin/ShowCalendarDialog.lua` — three call-site updates to use the renamed/widened functions and the new label helper, plus the dialog's "no regular collections" message now reads "no collections".
- **Modify** `CLAUDE.md` — remove the `Smart-collection support` bullet from the deferred list.
- **Modify** `README.md` — update the Use section to stop calling smart collections out of scope.

No files are created. No files are deleted.

---

## Conventions shared by every task

- Lua 5.1 only. 2-space indentation, `snake_case` locals.
- No unit tests for these changes; `CollectionReader` talks to `LrApplication` and `LrCollection` with no reachable surface for stubbing in the current harness.
- `bash tests/run_tests.sh` must still print `39 passed, 0 failed` at the end. That confirms we didn't accidentally damage `CalendarModel.lua` or a shared file.
- Commit style (conventional + HEREDOC body + co-author trailer):

  ```bash
  git commit -m "$(cat <<'EOF'
  <subject>

  <optional body>

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

- The plugin symlink is already in place (`~/Library/Application Support/Adobe/Lightroom/Modules/365Calendar.lrplugin → <repo>/365Calendar.lrplugin`). Restarting Lightroom picks up edited Lua source.

---

## Task 1: Widen `CollectionReader` and add `displayLabel`

**Files:**
- Modify: `365Calendar.lrplugin/CollectionReader.lua`

### Step 1.1: Replace the entire file contents

- [ ] **Overwrite `CollectionReader.lua` with this content:**

```lua
-- CollectionReader: loads photo data from a Lightroom collection.
-- Isolates LR catalog I/O so the rest of the plugin can stay pure or stubbed.

local LrApplication = import "LrApplication"

local M = {}

-- Returns an array of LrCollection objects (smart and regular) walked
-- recursively from the active catalog's root.
function M.listCollections()
  local catalog = LrApplication.activeCatalog()
  local result = {}

  local function walk(children)
    for _, c in ipairs(children) do
      if c:type() == "LrCollection" then
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

-- Returns the dropdown label for a collection: the qualified path, with
-- " [smart]" appended when the collection is rule-driven.
function M.displayLabel(collection)
  local name = M.qualifiedName(collection)
  if collection:isSmartCollection() then
    return name .. " [smart]"
  end
  return name
end

-- Returns the array of LrPhoto objects in the given collection.
function M.loadPhotos(collection)
  return collection:getPhotos()
end

-- Returns the first active LrCollection source (smart or regular) from
-- the Library's active sources, or nil if none is selected.
function M.activeCollection()
  local catalog = LrApplication.activeCatalog()
  local sources = catalog:getActiveSources() or {}
  for _, src in ipairs(sources) do
    if type(src) == "table" and src.type and src:type() == "LrCollection" then
      return src
    end
  end
  return nil
end

return M
```

- [ ] **Run model tests to confirm nothing else broke:**

  `bash tests/run_tests.sh`

  Expected: final line reads `39 passed, 0 failed`.

- [ ] **Do NOT commit yet** — the call sites in `ShowCalendarDialog.lua` still reference the old function names, so the plugin can't load. Task 2 restores a working state; they commit together.

---

## Task 2: Update the dialog's call sites

**Files:**
- Modify: `365Calendar.lrplugin/ShowCalendarDialog.lua`

### Step 2.1: Update the three call sites and the empty-catalog message

- [ ] **Apply three edits to `365Calendar.lrplugin/ShowCalendarDialog.lua`:**

1. Replace the call inside `run()` that lists collections and the empty-catalog message.

   Before:
   ```lua
       local collections = CollectionReader.listRegularCollections()
       if #collections == 0 then
         LrDialogs.message("365 Calendar", "No regular collections found in this catalog.", "info")
         return
       end
   ```

   After:
   ```lua
       local collections = CollectionReader.listCollections()
       if #collections == 0 then
         LrDialogs.message("365 Calendar", "No collections found in this catalog.", "info")
         return
       end
   ```

2. Replace the popup-item title source.

   Before:
   ```lua
       for _, c in ipairs(collections) do
         table.insert(collectionsList, {
           title = CollectionReader.qualifiedName(c),
           value = c,
         })
       end
   ```

   After:
   ```lua
       for _, c in ipairs(collections) do
         table.insert(collectionsList, {
           title = CollectionReader.displayLabel(c),
           value = c,
         })
       end
   ```

3. Replace the initial-source pick.

   Before:
   ```lua
       local currentCollection = CollectionReader.activeRegularCollection() or collections[1]
   ```

   After:
   ```lua
       local currentCollection = CollectionReader.activeCollection() or collections[1]
   ```

- [ ] **Verify no stale references remain:**

  `grep -n "Regular" 365Calendar.lrplugin/ShowCalendarDialog.lua`

  Expected: no output.

- [ ] **Run model tests:**

  `bash tests/run_tests.sh`

  Expected: `39 passed, 0 failed`.

- [ ] **Do NOT commit yet** — the feature isn't smoke-tested in Lightroom yet, and the docs in Tasks 3/4 haven't been updated. The UI + docs land in a single commit bundled with the smoke-test notes in Task 5.

---

## Task 3: Remove smart-collection deferral from `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

### Step 3.1: Drop the deferred-list bullet

- [ ] **Delete this line from the "deliberately deferred" bullet list in `CLAUDE.md`:**

  ```
  - Smart-collection support
  ```

  The surrounding bullets (Lightroom CC/Cloud, `.lrcat`, quarter/year view, click interactions) stay.

- [ ] **Do NOT commit yet** — bundled with the final commit in Task 5.

---

## Task 4: Update `README.md`

**Files:**
- Modify: `README.md`

### Step 4.1: Replace the Use section's step 1 wording

- [ ] **Find and replace the Use section step 1 in `README.md`.** Replace:

  ```
  1. In the Library module, select the collection you want to view — either
     pick it in the Collections panel in the left-hand inspector before
     opening the plugin, or switch to it later from the dropdown in the
     plugin's top bar. Selecting from the inspector is often quicker for
     nested collections.
  2. `Library > Plug-in Extras > Show 365 Calendar`. The dialog opens on
     whatever collection is currently selected in the inspector (falling
     back to the first regular collection if none is).
  ```

  with:

  ```
  1. In the Library module, select the collection you want to view —
     regular or smart. Pick it in the Collections panel in the left-hand
     inspector before opening the plugin, or switch to it later from the
     dropdown in the plugin's top bar. Smart collections appear in the
     dropdown with a trailing `[smart]` marker; selecting from the
     inspector is often quicker for nested collections.
  2. `Library > Plug-in Extras > Show 365 Calendar`. The dialog opens on
     whatever collection is currently selected in the inspector (falling
     back to the first collection if none is).
  ```

### Step 4.2: Remove the smart-collection deferral sentence

- [ ] **Find and delete this sentence in `README.md`** (appears just below the Use section):

  ```
  Smart collections, quarter-view and year-view layouts, and click interactions
  on cells are not supported — see `CLAUDE.md` for scope.
  ```

  Replace it with:

  ```
  Quarter-view and year-view layouts, and click interactions on cells,
  are not supported — see `CLAUDE.md` for scope.
  ```

- [ ] **Do NOT commit yet** — bundled with the final commit in Task 5.

---

## Task 5: Manual smoke test + commit

**Files:**
- All four modified files:
  - `365Calendar.lrplugin/CollectionReader.lua`
  - `365Calendar.lrplugin/ShowCalendarDialog.lua`
  - `CLAUDE.md`
  - `README.md`

### Step 5.1: Confirm the staged change set

- [ ] **Run:**

  `git status --short`

  Expected exactly (in any order):

  ```
   M 365Calendar.lrplugin/CollectionReader.lua
   M 365Calendar.lrplugin/ShowCalendarDialog.lua
   M CLAUDE.md
   M README.md
  ```

  If anything else appears, stop and reconcile before going further.

### Step 5.2: Lightroom smoke test

Restart Lightroom Classic so the plugin reloads from the edited files.
Open `Library > Plug-in Extras > Show 365 Calendar` and verify:

- [ ] Collection dropdown includes smart collections.
- [ ] Each smart collection's entry has a trailing ` [smart]` marker.
- [ ] Regular collection entries are unchanged.
- [ ] Picking a smart collection from the dropdown renders its membership correctly in both Calendar and Missing views.
- [ ] Selecting a smart collection in the Library inspector, then opening the plugin, opens the dialog on that smart collection.
- [ ] `Refresh` re-reads the smart collection's membership.

### Step 5.3: Commit

- [ ] **Run:**

  ```bash
  git add \
    365Calendar.lrplugin/CollectionReader.lua \
    365Calendar.lrplugin/ShowCalendarDialog.lua \
    CLAUDE.md \
    README.md

  git commit -m "$(cat <<'EOF'
  feat(plugin): include smart collections in the picker

  Drop the isSmartCollection filter from CollectionReader's list/active
  helpers, rename them to reflect the new scope, and add a displayLabel
  helper that appends " [smart]" for rule-driven collections. The dialog
  now lists every LrCollection and the Library-inspector source-pick
  path accepts smart collections too.

  Docs follow: CLAUDE.md no longer defers smart-collection support, and
  README.md's Use section calls out the [smart] marker.

  Smoke-tested in Lightroom Classic:
  - Dropdown lists smart collections alongside regulars, each with a
    trailing " [smart]" marker.
  - Picking a smart collection from the dropdown renders its current
    membership in Calendar and Missing views.
  - Selecting a smart collection in the Library inspector opens the
    dialog on that collection.
  - Refresh re-reads the smart collection's membership.

  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
  EOF
  )"
  ```

- [ ] **Verify:**

  `git log --oneline -1`

  Expected: the commit subject matches `feat(plugin): include smart collections in the picker`.

---

## Self-Review Checklist (run after completing all tasks)

- [ ] Model tests pass: `bash tests/run_tests.sh` → `39 passed, 0 failed`.
- [ ] No stale identifier references:
  - `grep -rn "Regular" 365Calendar.lrplugin/` — nothing from the plugin code (doc comments fine).
  - `grep -rn "listRegularCollections\|activeRegularCollection" 365Calendar.lrplugin/` — no hits.
- [ ] Spec requirements covered:
  - R1 smart collections in the dropdown — Tasks 1 + 2.
  - R2 `[smart]` marker — Task 1 (`displayLabel`) + Task 2 (call site).
  - R3 inspector selection honored — Task 1 (`activeCollection` widened) + Task 2.
  - R4 both views render for smart collections — no code change needed; smoke-tested in Task 5.
  - R5 Refresh reloads smart-collection membership — existing behavior; smoke-tested in Task 5.
- [ ] Docs in sync: `CLAUDE.md` no longer defers smart collections, `README.md` explains the marker.
