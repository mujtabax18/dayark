# Changes — Open-source maintenance refactor

**Date:** 19 October 2026  
**Change type:** Source-code organization only (no intended functional changes)

## Summary

The supplied DayArk `lib/` source has been reorganized so contributors can find feature code without scrolling through a single file containing many unrelated widgets and helpers.

- Refactored **26 existing Dart libraries** into their original entry files and **67 smaller Dart part files**.
- Kept all existing screen and service entry-point file paths, imports, exports, class names, method implementations, and signatures intact.
- Used Dart's `part` / `part of` mechanism, retaining the same library and private-member visibility. No new runtime dependency was introduced.
- Preserved the **original source text** of each moved declaration, including the existing synchronization, backup, database, network, UI, navigation, and form logic.
- Added `ARCHITECTURE.md` to explain the new layout and safe contribution practices.
- Added `tool/verify_refactor.py` plus `tool/refactor_manifest.json` for structural and one-time source-equivalence verification.

## Refactored areas

| Area | What was organized |
| --- | --- |
| Device synchronization | State models/DTOs separated from the existing sync service implementation; security, protocols, local port, and conflict-resolution logic left as-is |
| Portable backups | Status/result types and backup service separated into parts |
| Multimedia | Main dashboard state, media collection controls, gallery widgets, and viewer helpers grouped |
| Quotations | Quotation screen state, desktop prompt/review/form pages, cards, and quotation service types grouped |
| Invoices | Form state, business/customer selectors, data management tabs/editors, and desktop dashboard components grouped |
| Expenses | Expense workspace, navigation, overview, and category widgets grouped |
| Settings | Main settings screen and related dialogs/responsive layout helpers grouped |
| Habits | Detail, history, desktop dashboard, and habit editor/helper components grouped |
| Home | Home dashboard, layout customization, and quick-action UI helpers grouped |
| Family tree | Family detail views and relationship graph/painter implementation separated into parts |
| Navigation | Application shell, desktop sidebar, and finance dashboard components grouped |
| Scanner | Gallery and desktop components grouped |
| Tutorials | Tutorial navigation, detail, and guide components grouped |
| Meter readings | A reading-form helper moved into its own part |

Each refactored library keeps its original import path. The new files are located in a `parts/` directory next to their owning library; see `tool/refactor_manifest.json` for an exact file-by-file map.

## Functionality preservation and verification

**Automated static checks passed:**

1. **26/26 source reconstruction checks:** the source code reconstructed from each library and its parts has the same SHA-256 digest as the supplied pre-refactor source file. This validates that declarations were moved, not rewritten.
2. **88 Dart part relationships validated:** all existing and new `part` references were found, with matching `part of` ownership and no orphaned part files.
3. **358 other original archive files** remained byte-for-byte identical. This includes all source files not selected for the refactor and the other archived files.

Run the checks on the extracted archive:

```bash
python3 tool/verify_refactor.py
python3 tool/verify_refactor.py --verify-snapshot
```

The `--verify-snapshot` option checks the **initial refactor only**; after you intentionally edit application code, those old source hashes will naturally differ. The ordinary part-reference check remains useful for future work.

### What still needs project-side validation

The upload contained `lib/` only, not a complete Flutter project with `pubspec.yaml`, platform folders, and tests. The Flutter/Dart SDK was not available in this environment, so **`flutter analyze`, `flutter test`, and runtime smoke tests could not be run** here.

After merging these changes into the full project, run:

```bash
flutter pub get
flutter analyze
flutter test
```

Then smoke-test device pairing/sync, encrypted backups and restore, quotations, invoice editing, media, habits, family tree, navigation, and mobile/desktop layouts. See `ARCHITECTURE.md` for the checklist.

## Notes for future refactors

Some large **single classes** (notably the device-sync engine and several screen `State` classes) remain long within their own part files. Splitting their methods into new services, state controllers, or widgets would require code changes and regression tests; doing that without a complete build/test environment would risk functionality. This pass deliberately stops at **lossless, same-library extraction**.

No database migration, route change, API contract change, port change, crypto change, or dependency change was introduced. This does **not** constitute a runtime-tested compatibility guarantee.
