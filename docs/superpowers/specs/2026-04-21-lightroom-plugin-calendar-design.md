# 365 Project — Lightroom Calendar Plugin Design

**Date:** 2026-04-21
**Status:** Approved (design phase)
**Scope:** Lightroom Classic plugin sub-project only. The macOS/iOS apps and any shared data model are deliberately out of scope for this spec.

## Purpose

A Lightroom Classic plugin that displays a calendar viewer for a user-selected collection, laid out as a single-month grid with photo thumbnails on days that have photos and tinted placeholder cells on days that don't. Lets a photographer running the 365 Project visually identify missing days inside Lightroom without leaving the app.

## Decisions

| Question | Decision |
|---|---|
| View scope | Single month at a time, with prev/next navigation |
| Missing-day treatment | Tinted empty cell (soft red) with the day number |
| Click behavior on cells | None (view-only) |
| Date source | `dateTimeOriginal` raw metadata from each photo |
| Multiple photos per day | Show earliest-captured photo as primary; render `"+N"` badge on the cell for additional photos that day |
| Collection selection | User-picked from a popup of regular collections |
| Smart collections | Out of scope; excluded from the collection picker |
| Weekday start | Sunday (default; user-configurable deferred) |
| Initial month on open | Current calendar month |
| Cross-year navigation | Free; December→next rolls to January of next year |
| Refresh | Explicit Refresh button re-reads the collection; model is otherwise cached for the session |

## Architecture

Standard Lightroom Classic plugin layout:

```
365Calendar.lrplugin/
├── Info.lua                    # plugin manifest + menu registration
├── ShowCalendarDialog.lua      # entry point, runs on menu click
├── CollectionReader.lua        # loads photos from a collection
├── CalendarModel.lua           # bins photos by local-day from captureTime
├── CalendarView.lua            # builds the LrView UI tree
└── strings/
    └── TranslatedStrings.txt   # localized UI strings
```

### Module responsibilities

- **Info.lua** — registers the plugin and contributes a menu item to `Library > Plug-in Extras` via `LrLibraryMenuItems`.
- **ShowCalendarDialog.lua** — entry point. Wraps everything in `LrTasks.startAsyncTask` (LrView + catalog access require async context). Owns the navigation loop that re-presents the dialog on prev/next/refresh.
- **CollectionReader.lua** — given an `LrCollection`, returns an array of `LrPhoto` along with any metadata the model needs. Isolates catalog API calls so the rest of the plugin is testable against stub data.
- **CalendarModel.lua** — pure Lua. Ingests photos, bins them by local calendar day, exposes `cellsForMonth(year, month)` returning an array sized to that month's day count with per-cell `{ day, primary, extras }`. No dependencies on LR APIs.
- **CalendarView.lua** — builds the `LrView` UI tree for a given model + month + collection list. Pure function of state.

### Dependency graph

```
ShowCalendarDialog → CollectionReader → (LrApplication, catalog APIs)
                   → CalendarModel    → (pure Lua)
                   → CalendarView     → (LrView, LrColor)
```

The point of this split: CalendarModel can be exercised in isolation (Lua REPL, unit-test style), CalendarView gets a fully-prepared model and only renders, and CollectionReader is the only module that talks to the Lightroom catalog.

## Data flow

### Capture time extraction

```lua
local cocoaSeconds = photo:getRawMetadata("dateTimeOriginal")
-- Cocoa epoch = 2001-01-01 00:00:00 UTC; Unix offset = 978307200
local unixSeconds = cocoaSeconds + 978307200
local t = os.date("*t", unixSeconds)  -- local time: { year, month, day, ... }
```

Interpreted as local time — no timezone handling beyond what `os.date` already does. Photos lacking `dateTimeOriginal` are skipped (not counted in any cell, not surfaced).

### CalendarModel interface

```lua
-- Construction: single pass over all photos, bins by (year, month, day)
local model = CalendarModel.new(photos)

-- Query: returns an array sized to the month's day count
-- Each element: { day = N, primary = <LrPhoto> or nil, extras = <integer ≥ 0> }
local cells = model:cellsForMonth(year, month)
```

Within a day bin, photos are sorted by ascending captureTime. The first is `primary`; `extras` is the count of additional photos that day (0 if only one photo, N-1 if N photos).

### Collection picker

At dialog open:

1. Call `LrApplication.activeCatalog():getChildCollections()` (recursively walked) to enumerate regular collections.
2. Exclude smart collections (`collection:isSmartCollection()` → true means skip).
3. Build popup options labeled with folder-path prefixes for disambiguation (e.g., `Trips/2026/Iceland`).
4. If the user has an active collection selected in the Library panel, preselect it; otherwise preselect the first in the list.

### Caching

The binned day-map is computed once when a collection is loaded and kept in the dialog's state across navigation iterations. Prev/Next only re-renders from the cached model. Refresh re-reads the collection via `CollectionReader` and rebuilds the model.

## UI layout

Dialog structure, top to bottom:

```
┌──────────────────────────────────────────────────────────┐
│ Collection: [ Project 365 ▾ ]   [ Refresh ]              │
│ [ ◀ ]         April 2026              [ ▶ ]              │
│ ─────────────────────────────────────────────────────    │
│  Sun   Mon   Tue   Wed   Thu   Fri   Sat                 │
│  [  ] [  ] [img] [img] [img] [img] [img]                 │
│  [img] [img] [MIS] [img] [img] [img] [img]               │
│  ...                                                     │
│                                           [ Close ]      │
└──────────────────────────────────────────────────────────┘
```

- **Top bar:** `f:row` containing a collection popup (`f:popup_menu`) and a Refresh button (`f:push_button`).
- **Nav bar:** `f:row` with Prev button, centered month label (`f:static_text`), Next button.
- **Weekday header row:** `f:row` of 7 `static_text`s, Sunday through Saturday.
- **Grid:** `f:column` of up to 6 `f:row`s, each with 7 cells. Leading blanks fill from the 1st's weekday; trailing blanks fill the last row to align.
- **Close button:** standard modal dismiss.

### Cell rendering

**Present cell (primary photo exists):** `f:place` overlay with three children:

```
f:place {
  f:catalog_photo { photo = primary, width = 80, height = 80 },  -- base
  f:static_text { title = tostring(day), ... , place_horizontal = 0, place_vertical = 0 },  -- top-left
  f:static_text { title = "+"..extras, visible = extras > 0, ..., place_horizontal = 1, place_vertical = 0 },  -- top-right
}
```

The day number and badge sit on top of the thumbnail. Text uses a light color with a subtle shadow (or, if LrView shadows aren't supported, a semi-opaque dark background behind the text via a wrapping `f:view`).

**Missing cell:** `f:view` at the same 80×80 footprint, `background_color = LrColor(0.95, 0.85, 0.85)`, containing a centered day-number `static_text` with `text_color = LrColor(0.55, 0.25, 0.25)`. Same external dimensions as photo cells so the grid aligns.

### Navigation mechanism

LrView does not support rebinding a container's children after the dialog is presented. The grid is re-rendered by dismissing and re-presenting the modal with updated state:

```lua
-- Pseudocode
local state = { collection = ..., model = ..., year = ..., month = ... }
while true do
  local action = LrDialogs.presentModalDialog {
    contents = CalendarView.build(state),
    actionVerb = nil,  -- custom buttons set the action
    ...
  }
  if action == "prev" then
    state.year, state.month = rollMonth(state.year, state.month, -1)
  elseif action == "next" then
    state.year, state.month = rollMonth(state.year, state.month, 1)
  elseif action == "refresh" then
    state.model = CollectionReader.load(state.collection)
  elseif action == "switch_collection" then
    state.collection = <new selection>
    state.model = CollectionReader.load(state.collection)
  else
    break  -- Close
  end
end
```

Navigation buttons are custom `f:push_button`s that call `LrDialogs.stopModalWithResult(propertyTable, "prev" | "next" | ...)`. Model is cached, so re-presenting is only a view rebuild — no catalog re-read on prev/next.

## Edge cases

- **Photos without `dateTimeOriginal`** — skipped silently; not counted, not shown.
- **Leap February** — `os.date` already produces correct day counts (29 in leap years); no special case.
- **Collection with zero photos** — every cell renders as missing; month label still shows.
- **Selected collection deleted between sessions** — on next open, if the previously selected collection is gone, fall back to first available.
- **Year rollover at December→next or January→prev** — standard; `rollMonth` handles.
- **Cameras with wrong clock** — accepted as-is; photo lands on whatever day its `dateTimeOriginal` says. Not the plugin's job to guess.

## LrView verification points (for implementation)

These are small API details worth prototyping before committing to the final rendering code:

1. Does `static_text` accept `background_color` directly, or must the badge be wrapped in `f:view` for the dark pill behind text?
2. Does `f:place` reliably support `place_horizontal` / `place_vertical` on children for corner-pinning at 0/1?
3. Is `LrDialogs.stopModalWithResult` the right primitive for custom action buttons, or should we use observable properties and a post-dismiss dispatch?

None are design blockers. They may shift minor details of `CalendarView.lua`.

## Out of scope (deferred)

- Smart collections (members not materialized; evaluating rules from Lua is painful).
- Quarter-view and year-view layouts (single month only for v1).
- Click interactions (open in Library, etc.).
- Week-start configuration (Sunday hardcoded for v1).
- iOS / macOS companion apps.
- Direct `.lrcat` SQLite reading (plugin stays inside Lightroom's API surface).

## Testing strategy

- **CalendarModel** is pure Lua and can be exercised with hand-built photo stub tables (objects with a `getRawMetadata` method) — favor this for the bulk of logic testing.
- **CollectionReader** is thin; covered by manual smoke-testing against a real collection.
- **CalendarView** — visual verification via the plugin itself; no automated UI tests practical within LR.
