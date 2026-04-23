# 365 Project — Lightroom Plugin

A Lightroom Classic plugin that shows a month-grid calendar view of a
collection: thumbnails and day-number labels on days you shot, empty cells on
days you didn't. It helps photographers in a 365 Project see their missing
days at a glance.

## Install

1. Download `365Calendar-<version>.lrplugin.zip` from the
   [latest release](../../releases/latest) and unzip it somewhere you'll keep
   it (the plugin runs from wherever it lives on disk).
2. In Lightroom Classic: `File > Plug-in Manager… > Add`, then point at the
   unzipped `365Calendar.lrplugin` directory.
3. Confirm the plugin shows as **Enabled**.

## Use

### 1. Pick a collection and open the plugin

In the Library module, select the collection you want to view — regular
or smart. Pick it in the Collections panel in the left-hand inspector
before opening the plugin, or switch to it later from the dropdown in
the plugin's top bar. Smart collections appear in the dropdown with a
trailing `[smart]` marker.

Open the plugin from `Library > Plug-in Extras > Show 365 Calendar`:

<img src="img/How%20To%20Launch.jpeg" alt="Library menu showing Plug-in Extras > Show 365 Calendar" width="700">

The dialog opens on whatever collection is currently selected in the
inspector (falling back to the first collection if none is).

### 2. Calendar view

The Calendar view is a month grid: thumbnails on days with photos,
empty cells on days without. Each present-day cell carries a `Day N`
label counting from the collection's earliest photo. Navigate with `<`
/ `>` (the `>` button disables once you reach the current month).
`Refresh` reloads the active collection.

<img src="img/365%20Project%20LR%20Plugin%20Calendar.jpeg" alt="Calendar view with photo thumbnails and Day N labels on days with photos, empty cells on days without" width="520">

### 3. Missing view

Click `Missing` to swap the grid for a chronological list of every
date without a photo between your earliest photo and today. Entries
are grouped under a bold year heading; each row shows the month and
day with the project day in parentheses — for example, `Feb 18 (Day
56)`. A count of missing days sits at the top of the list.

<img src="img/365%20Project%20LR%20Plugin%20Missing.jpeg" alt="Missing view listing dates without photos grouped by year" width="520">

---

Quarter-view and year-view layouts, and click interactions on cells,
are not supported — see `CLAUDE.md` for scope.

## Develop

Install from source by symlinking the plugin into Lightroom's modules folder:

    ln -s "$PWD/365Calendar.lrplugin" \
      "$HOME/Library/Application Support/Adobe/Lightroom/Modules/365Calendar.lrplugin"

Run the unit tests:

    bash tests/run_tests.sh

Design docs live in [`docs/superpowers/specs/`](./docs/superpowers/specs/).

## Release

Releases are cut by pushing a version tag:

    scripts/build.sh                 # dry run — produces dist/ locally
    git tag 1.0.0
    git push origin 1.0.0

The `release` GitHub Actions workflow builds the plugin zip and attaches it
to a GitHub Release for that tag. The tag must match the `VERSION` in
`365Calendar.lrplugin/Info.lua`.

## License

MIT — see [`LICENSE`](./LICENSE).
