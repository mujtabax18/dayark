# DayArk — genealogy_chart integration (6 November 2026)

## Required dependency (the uploaded Archive contains `lib/` files, not `pubspec.yaml`)

Add the following under `dependencies:` in your **project-root** `pubspec.yaml`:

```yaml
genealogy_chart: ^1.0.2
```

Then execute:

```bash
flutter pub get
flutter analyze
flutter test
```

Do **not** replace an existing `pubspec.yaml` with a new one. Keep all other dependencies intact.

## Updated source files

- `screens/family_tree/view/parts/family_tree_detail_screen_tree_tab.dart`: the full-screen Tree tab now defaults to the package chart; switch to Classic 2D/3D whenever desired.
- `screens/family_tree/view/family_tree_detail_screen.dart`: imports the new chart screen.
- `screens/family_tree/view/family_genealogy_chart.dart`: local-photo cards, compact mode, pinch/drag, search, zoom, fit-to-screen, details and quick family-member actions.
- `screens/family_tree/services/family_chart_adapter.dart`: converts DayArk people/relationships to package models without changing the database.

## Preserved DayArk features

The existing repository, database schema, multiple member photos, memory albums, participant tagging, edit/quick-add sheets, people list, album tab, and original 2D/3D chart remain unchanged. The new genealogy chart is read-only as a diagram, **not** a different data store. Edits are still persisted by DayArk's own repository and reloaded into the chart. Package drag-drop editing is intentionally disabled to prevent unsaved changes and invalid relationships.

`genealogy_chart`'s family mode natively visualizes parent/child and partner/spouse links. It does not model standalone siblings or DayArk-specific guardian/other relationship types. These are preserved and fully drawn in **Classic 2D/3D**, instead of inventing parents or incorrectly labeling guardians as biological parents. A hint appears when such relationships are present. Siblings with a known shared parent appear under the same parent in the new chart.

The chart uses an adapter that treats spouses/partners as a contiguous household unit, protecting against the problem where a spouse appears in the sibling group. For complex marriage graphs the package has its own grouping limitations; the original DayArk renderer remains an alternative.

## Manual regression checks

1. Open a tree with father, mother, two siblings and one sibling's wife. Confirm wife is directly alongside their spouse in **Family chart**, not between the siblings.
2. Test grandparents above parents and children below them, including a member with two recorded parents.
3. Test separate, disconnected family branches and multiple spouses.
4. Long-press a chart card, add parent/child/spouse/sibling, verify persistence after closing and reopening the tree.
5. Tap a person; open Details > Photos and create an album; check album appears in Albums tab.
6. Verify drag, pinch, zoom, fit, compact cards, native chart search and selection on Android/iOS/Desktop.
7. Switch to Classic; verify 2D/3D, all custom relationships, arrows and all existing add actions.
8. Verify dark/light theme, long names, narrow screens, full-screen gestures, and tab navigation.

## Validation caveat

The uploaded archive did not include your root `pubspec.yaml`, and Flutter/Dart SDK binaries are not available in this editing environment. Therefore `flutter pub get`, `flutter analyze`, and a device build could not be run here. Run the three commands above in your actual project after adding the dependency. No database migration is required.

Package API verified from the published genealogy_chart 1.0.2 documentation and the package's public source:
https://pub.dev/packages/genealogy_chart
