# DayArk Life Archives — Right-side details and album galleries

## Changes

- On Web/Desktop (at least 840 logical pixels), selecting a memory or life event opens a **right-side inspector inside the existing Life Archive workspace** rather than pushing a new route or opening a sheet.
- Wider workspaces show the list and inspector side-by-side. Narrower desktop windows show a right-anchored inspector within the workspace; the sidebar and existing navigation remain intact.
- Selecting another row/card updates the inspector without navigating away. Selected memory and event cards/rows show a highlighted outline/background.
- Event details include linked memory albums as a thumbnail **grid**. Clicking an album opens that album's gallery in the same inspector; Back returns to the event.
- All album covers now open memory details instead of going directly to the photo slider. The memory details display a **gallery grid first**, followed by the story and tagged people. Clicking an *individual photo* still opens the full-screen zoomable/swipeable viewer.
- Edit/delete/add-memory actions reuse the existing form sheets and repositories and refresh the active inspector using record IDs.
- Desktop archive theme selection and native WebView suspension remain in place; mobile uses its existing full-screen detail pages, now gallery-first.

## Integration

Merge the supplied directory tree into the project's existing Dart source tree (the ZIP contains a source snapshot, not a Flutter project with pubspec.yaml). The new file is `screens/family_tree/view/life_archive_inspector_panel.dart` and is imported by `family_tree_detail_screen.dart`.

## Suggested device checks

1. On Linux, Windows and Web at 1920px/1440px widths: open the Memories tab, select an album cover, verify the right inspector and the grid; click a thumbnail to view it full screen and close it to return to the inspector.
2. Open an Event, click a linked memory thumbnail, verify the gallery replaces event details *inside the inspector*; Back returns to the event; Close returns to the management view.
3. Resize the application between 840–1300px; the right inspector should be workspace-anchored rather than a new route or bottom sheet. Below 840px the mobile full-page details should remain available.
4. Apply search/sort in Memories or search/type in Events, open/close an inspector, and confirm the prior filters and scroll position remain.
5. Edit/delete/add records through inspector controls, verify displayed content refreshes, deleted selections close, and other records are preserved.
6. From Network, open a life event and check the native 3D WebView does not paint over the inspector. Close or switch tabs and verify the graph returns.
7. Check light/dark and archive color presets, including readability of photo grid, selection highlights, and form dialogs.

## Validation limits

Source-level regression tests run using `python qa/test_life_archive_inspector.py` and existing tests under `qa/`. This environment does not provide a Flutter SDK or a complete Flutter project, so `flutter analyze`, widget tests and platform runtime tests must be performed after merging into DayArk.
