# DayArk — Life Archives web/desktop admin-style interface

## Updated in this release

- **Life Archives landing page** (`family_tree_home_screen.dart`): dedicated desktop workspace with a navigation sidebar, overview statistics (archive/person/event/memory totals), a searchable archive library, large cover cards, edit/delete menus, and recent-first ordering. The phone UI remains the existing list-based design.
- **Inside an archive** (`parts/family_tree_detail_screen_state.dart`): desktop sidebar for **Network / People / Memories / Events**, breadcrumbs, contextual create buttons, Appearance shortcut, quick statistics and a return-to-archives action. The Network canvas retains maximum available width without a floating button covering its interactive graph.
- **Memories** (`parts/family_tree_detail_screen_tree_tab.dart`): photo-first album/photos library; desktop query, sorting (newest, oldest, title), adaptive grid columns, and full-screen swipe/zoom image viewing. Album captions open full-page detail routes.
- **Events** (`parts/family_tree_detail_screen_life.dart`): search by title, type, description and location; type filtering; new/old sorting; full-width data table on wide workspaces and responsive event cards at narrower desktop widths. Event selection opens a full page.
- **Memory and event details** (`life_archive_detail_pages.dart`, `life_archive_desktop_detail_pages.dart`): full routes with max-width workspaces, wider gallery/content panels, metadata, people, and linked event/memory sections. Existing edit, delete, add-memory and navigation callbacks are preserved. Phone versions remain unchanged.
- **Themes**: all new admin controls use the archive's selected Flutter ColorScheme, so existing follow-app/system/light/dark and accent presets continue to apply.
- **Web image display safety** (`life_archive_media.dart` and `family_photo_gallery.dart`): image widgets accept browser-accessible HTTP(S), data URI and browser blob URLs on web, and local files on native platforms. Unreadable paths do not trigger native filesystem operations in a browser.

## Breakpoints

The main workspaces switch to the admin layout when their available width reaches **840 logical pixels**. The desktop sidebar consumes 224 px; content grids, cards and table columns adapt to the remaining width. At narrower widths, the app uses its existing mobile screens.

## Web storage note

The codebase's Drift SQL layer already has web options, but `FamilyTreeMediaService` still copies/deletes images using `dart:io` and native directories. **This UI update does not migrate that native media persistence system.** Browser image upload, durable storage (IndexedDB/OPFS or a supported backend) and any legacy path migrations must be implemented separately for complete end-to-end Web photo CRUD. Missing/local native paths are shown safely instead of crashing the web UI. Also ensure the existing `sqlite3.wasm` and `drift_worker.dart.js` assets are deployed for Drift Web.

## Integration

1. The ZIP represents the `lib/` source tree. Copy the updated files into your existing app's `lib/` folder, preserving paths. Existing packages and backend APIs remain unchanged.
2. The new helper files under `lib/screens/family_tree/view/` are **required**: `life_archive_desktop_widgets.dart`, `life_archive_desktop_detail_pages.dart`, `life_archive_media.dart`.
3. Run `dart format lib/screens/family_tree/view`, `flutter analyze`, and platform-specific Flutter builds from the **full project** (the supplied ZIP contains Dart sources, not `pubspec.yaml` or all platform assets).
4. On web and desktop, verify widths around 840, 1024, 1280 and 1600 logical pixels, plus light/dark/preset palettes and longer text at increased text scaling.

## Regression checklist

- Landing page: create/edit/delete/open archive; search, clear search, reload; overview figures update after saves and deletes.
- Archive desktop sidebar: Network, People, Memories and Events all open; add actions use existing forms; Network canvas remains draggable and can be reopened after full-page previews.
- Memories: albums vs all photos, album cover click vs caption click, search and sort, text-only albums, image viewer swiping/zooming and back navigation.
- Events: filters, sort, table and compact card modes, full event page; tagged people; linked memories; add/edit/delete confirmation and navigation.
- Appearance: all existing modes/presets apply to workspace, overlays, details and edit forms; settings survive app restart.
- Web: test browser images from URL/data URI, verify unsupported native paths degrade gracefully; test native media separately on Linux/Windows.

**Verification:** Source structure, relative imports and balanced syntax delimiters were checked here. Flutter SDK, full `pubspec.yaml`, wasm assets and a running application were not supplied, so `flutter analyze`, compiled desktop/web builds and runtime UI tests are still required in the complete DayArk project.
