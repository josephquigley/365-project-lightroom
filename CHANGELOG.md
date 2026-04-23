# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Smart collection support — smart collections now appear in the collection dropdown with a trailing `[smart]` marker, can be picked from the Library inspector, and render correctly in both Calendar and Missing views.

### Fixed

- Calendar grid now has leading edge padding that visually balances the existing trailing gutter reserved for the vertical scrollbar.

## [1.1.0] - 2026-04-22

### Added

- Calendar / Missing view toggle in the top bar.
- Missing view listing every date without a photo between the collection's earliest photo and today. Entries are grouped under a bold year heading and formatted as `MMM D (Day N)`.
- Header line above the top bar showing today's date and the current 365-project day count, e.g. `April 22, 2026 — Day 22`.
- "N missing" summary, "No photos in this collection.", and "You're caught up — no missing days." messages to cover empty-state cases in the Missing view.

### Changed

- Calendar grid and weekday header are now centered together in the dialog so the grid stays visually balanced when the window is wider than the grid itself.
- Top bar reorganized into a shared header row (date + Day N) above the collection picker, view toggle, and refresh button.

## [1.0.0] - 2026-04-22

### Added

- Initial release of the 365 Project Calendar plugin for Lightroom Classic.
- Month-grid calendar view of a chosen collection, with photo thumbnails on days that have photos and soft-red empty cells on days that don't.
- `Day N` labels under present-day cells showing the 365-project day number (earliest photo in the collection is Day 1).
- `<` / `>` buttons to navigate month-by-month; `>` is disabled once the selected month reaches the current calendar month.
- `Refresh` button to reload the active collection's photos.
- Collection dropdown in the top bar for switching between regular collections without closing the dialog.
- Opens on whichever regular collection is currently selected in the Library inspector, falling back to the first regular collection in the catalog.
- Dialog window position persisted across close/re-open cycles.
- `scripts/build.sh` plus a GitHub Actions release workflow that publishes `365Calendar-<version>.lrplugin.zip` when a version tag is pushed.

[1.1.0]: https://github.com/josephquigley/365-project-lightroom/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/josephquigley/365-project-lightroom/releases/tag/1.0.0
