# Missing-Days View — Design

Date: 2026-04-22

## Goal

Add a second view mode to the 365 Calendar dialog that lists only the days
without a photo between the collection's earliest photo and today. Both
views display the current project-day count.

## Requirements

1. A segmented toggle in the top bar switches between two view modes:
   **Calendar** (existing month grid) and **Missing** (list of dates with no
   photo).
2. Both modes show the current project day as `Day N`, where `N` is the
   inclusive count from the earliest photo's date to today
   (first photo's date = Day 1).
3. The Missing view shows a count of missing days as a secondary line:
   `N missing`.
4. All existing behaviors (month navigation in the calendar view, collection
   selection, refresh, window position persistence) continue to work.
5. Click interactions on cells remain out of scope.

## Non-goals

- Smart-collection support.
- Quarter- or year-view layouts.
- Persisting the selected view mode across dialog sessions.
- Reacting to photos added/removed during a session without a refresh.

## Model API (`CalendarModel.lua`)

Two new instance methods:

```
model:projectDayOf(today)
  today  -> { year = Y, month = M, day = D }
  return -> integer, or nil if the model has no photos

model:missingDays(today)
  today  -> { year = Y, month = M, day = D }
  return -> array of { year, month, day, project_day } in ascending order
```

Semantics:

- `projectDayOf(today)` returns `days_between(_start, today) + 1`. Value is
  `1` when `today == _start`. Value is negative when `today` is before
  `_start` (future-first-photo case) — the literal value is returned so the
  UI can surface the anomaly rather than hide it.
- `projectDayOf(today)` returns `nil` only when the model has no photos
  (`_start == nil`).
- `missingDays(today)` walks every date from `_start` through `today`
  inclusive and emits entries for dates not present in `_bins`. Returns
  `{}` when the model is empty or when `today` precedes `_start`.
- Each missing-day entry's `project_day` equals `projectDayOf(entry)` for
  the entry's date.

Both methods are keyed on a caller-supplied `today` so the model remains
deterministic and unit-testable, matching the existing `cellsForMonth`
pattern.

## View changes (`CalendarView.lua`)

### Top bar (shared across both modes)

```
[Collection ▼]   [ Calendar | Missing ]                    Day 22
```

- Collection popup — unchanged.
- Two `f:push_button`s form the segmented toggle. Clicking a button closes
  the modal with result `"view:calendar"` or `"view:missing"`; the dialog
  loop re-presents in the chosen mode. The button matching the current mode
  is rendered as disabled to act as a visual "selected" state.
- The Day N label on the right is an `f:static_text`. When `_start` is nil
  (empty collection), it reads `Day —`.

### Calendar mode (existing behavior)

Nav bar, weekday header, month grid — unchanged.

### Missing mode (new)

- Secondary line under the top bar:
  - Empty collection: `No photos in this collection.`
  - Non-empty collection with zero missing days: `You're caught up — no
    missing days.`
  - Otherwise: `N missing` where N is `#state.missingDays`.
- No nav bar (the list is not organised by month).
- A grid built by a new `_missingGrid(f, missingDays)` helper. Cells are
  packed 7 across by list index (no leading blanks, no month dividers, no
  weekday header). Each cell is rendered by a new `_missingProjectCell(f,
  entry)` helper that reuses `_missingCell`'s soft-red box with the day of
  month, and adds a `Day N` line beneath (mirroring the `Day N` label under
  present cells in the calendar view).

All new helpers live in `CalendarView.lua` alongside the existing cell
builders. `M.build(state, properties)` branches on `state.view` for the
content region; the top bar is identical across modes.

## Dialog wiring (`ShowCalendarDialog.lua`)

- A new loop-local `viewMode` starts at `"calendar"`.
- `buildState` gains:
  - `state.view` = current `viewMode`.
  - `state.today` = `{ year, month, day }` of `os.date("*t")` once per
    re-present.
  - `state.todayProjectDay` = `model:projectDayOf(state.today)`.
  - When `state.view == "missing"`: `state.missingDays =
    model:missingDays(state.today)`.
- The modal result handler is extended:
  ```
  elseif result == "view:calendar" then viewMode = "calendar"
  elseif result == "view:missing"  then viewMode = "missing"
  ```
  Falls through the existing `prev` / `next` / `refresh` / close cases.
- Navigation in missing mode is a no-op (no nav bar is rendered, so no
  `prev`/`next` buttons fire).

## Edge cases

| Situation | Top bar | Missing view body |
|-----------|---------|-------------------|
| Empty collection | `Day —` | `No photos in this collection.` |
| First photo is today (Day 1, zero missing) | `Day 1` | `You're caught up — no missing days.` |
| First photo dated in the future | literal negative value (e.g. `Day -3`) | empty grid (no missing entries) |
| Very large gap (many missing days) | `Day N` | grid scrolls via the existing `scrolled_view` |

## Testing

### Unit tests — `tests/test_calendar_model.lua`

`projectDayOf`:

- `nil` when the model has no photos.
- `1` when `today` equals `_start`.
- `N+1` when `today` is N days after `_start`.
- Negative when `today` precedes `_start`.
- Correct across a month boundary.

`missingDays`:

- `{}` for an empty model.
- `{}` when all days from `_start` to `today` have photos.
- One entry for a single one-day gap.
- Entries in ascending date order.
- Each entry's `project_day` matches `projectDayOf` for that date.
- `{}` when `today` precedes `_start`.
- Only missing days appear — present dates are excluded.
- Correct across a month boundary and through leap February.

### Manual smoke test (Lightroom Classic)

Record the steps in the commit message that lands the UI changes:

1. Open the plugin on a collection with photos — `Calendar` toggle is the
   disabled (selected) button, nav bar shows the current month, top bar
   shows `Day N`.
2. Click `Missing` — dialog re-presents: nav bar is gone; missing-days grid
   renders; secondary line reads `N missing`.
3. Click `Calendar` — month grid returns with preserved window position.
4. Switch the collection while in Missing mode — the list refreshes against
   the new collection's photos; top bar `Day N` updates.
5. Open the plugin on an empty collection — `Day —` in top bar, appropriate
   empty-state message in Missing mode.
6. Open on a collection where every day from first photo to today has a
   photo — Missing mode shows the caught-up message.

## Files changed

- `365Calendar.lrplugin/CalendarModel.lua` — two new methods.
- `365Calendar.lrplugin/CalendarView.lua` — top-bar toggle + Day N slot,
  missing-grid/cell helpers, `build` branches on `state.view`.
- `365Calendar.lrplugin/ShowCalendarDialog.lua` — `viewMode` state, modal
  result handling for `view:*`, `today`/`todayProjectDay`/`missingDays` in
  `buildState`.
- `tests/test_calendar_model.lua` — tests for the two new model methods.
