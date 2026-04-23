# Smart Collection Support — Design

Date: 2026-04-23

## Goal

Allow the 365 Calendar plugin to read photos from Lightroom smart
collections in addition to regular (static) collections.

## Background

Smart collections are `LrCollection` objects whose membership is
rule-driven rather than user-curated. The SDK exposes them through the
same API as regular collections, differing only in the return value of
`isSmartCollection()`. `getPhotos()` returns the rule's current matches.

Today `CollectionReader` filters smart collections out in two places,
and `ShowCalendarDialog` consumes only that filtered list. Removing the
filter is the core of the feature.

## Requirements

1. Smart collections appear in the in-plugin collection dropdown
   alongside regular collections, interleaved in the same
   catalog-walk order already used for regular collections (no
   separate grouping).
2. Smart collections carry a trailing `[smart]` marker in the dropdown
   label, e.g. `Trips/2026/Iceland [smart]`.
3. Selecting a smart collection in the Library inspector and opening
   the plugin opens the dialog on that collection — the same behavior
   as regular collections.
4. Once a collection is selected (by either route), both Calendar and
   Missing views render identically regardless of whether the
   collection is smart or regular.
5. `Refresh` re-reads the collection's current membership, which is
   particularly relevant for smart collections whose rules can
   reclassify photos.

## Non-goals

- Smart-collection-aware editing (authoring / editing rules).
- Auto-refresh when the catalog changes behind the dialog.
- Showing or previewing smart-collection rules in the plugin UI.
- Differentiating smart and regular collections through any channel
  other than the dropdown label suffix.

## `CollectionReader.lua` API

Before:
```
listRegularCollections()   -- non-smart only
activeRegularCollection()  -- non-smart only
qualifiedName(collection)
loadPhotos(collection)
```

After:
```
listCollections()          -- all LrCollection objects, smart and regular
activeCollection()         -- first active LrCollection source, smart or regular
qualifiedName(collection)  -- unchanged
displayLabel(collection)   -- qualifiedName + " [smart]" when isSmartCollection()
loadPhotos(collection)     -- unchanged
```

The `isSmartCollection()` filter is dropped from `listCollections` and
`activeCollection`. `qualifiedName` stays path-prefix-only so external
callers that still want a bare name get one. `displayLabel` is the
presentation-layer helper used by the dialog.

## Dialog changes (`ShowCalendarDialog.lua`)

- Call `CollectionReader.listCollections()` instead of
  `listRegularCollections()`.
- Call `CollectionReader.activeCollection()` instead of
  `activeRegularCollection()`.
- Build popup entries as
  `{ title = CollectionReader.displayLabel(c), value = c }` — one-line
  substitution, no other changes to state or loop handling.

## View changes

None. `CalendarView.lua` is unaware of collection types.

## Model changes

None. `CalendarModel` operates on photos, not collections.

## Docs

- `CLAUDE.md`: remove the `Smart-collection support` bullet from the
  "deliberately deferred" list.
- `README.md`: update the Use section from "Select a regular (non-smart)
  collection" to "Select a collection (regular or smart)"; drop the
  parenthetical deferring smart collections.

## Testing

`CollectionReader.lua` is not unit-tested: every function invokes the
Lightroom SDK. Building a test harness for this change is
disproportionate to the diff's size.

### Manual smoke test (record outcome in commit message)

1. Plugin dropdown lists smart collections alongside regulars, with
   `[smart]` suffix on smart ones.
2. Selecting a smart collection from the dropdown renders the calendar
   and Missing views correctly from its current membership.
3. Selecting a smart collection in the Library inspector and opening
   the plugin opens on that collection.
4. `Refresh` re-reads the smart collection's membership.

## Files changed

- `365Calendar.lrplugin/CollectionReader.lua` — rename, drop filters,
  add `displayLabel`.
- `365Calendar.lrplugin/ShowCalendarDialog.lua` — call-site updates.
- `CLAUDE.md` — deferred-list update.
- `README.md` — Use section wording.
