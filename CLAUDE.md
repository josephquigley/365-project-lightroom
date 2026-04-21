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
