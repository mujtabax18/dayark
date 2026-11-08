# Media Studio ↔ Life Archive ↔ Scanner (7 November 2026)

## Delivered

- **One global appearance**: Life Archive no longer has a separate Appearance button, selector, theme mode, palette, or per-tree theme persistence. It inherits DayArk's light/dark/preset settings exactly like the rest of the app. Legacy preference keys are ignored; no user data is deleted.
- **Memory albums in Media Studio**: New Connected libraries area on mobile and desktop Collections home, plus desktop sidebar links. Recent memory albums are previewed with cover thumbnails, archive labels, photo counts, and direct-open actions.
- **Scanned documents in Media Studio**: Connected libraries shows existing scanner documents with previews and page counts. Tap to open the original multipage scanned document view with existing editing/export actions.
- **Searchable linked libraries**: Browse all memory albums across all life archives or all scanner documents. Search by memory title/description/archive name or by document title/tags, respectively.
- **Preserves the original data**: The linked lists query `FamilyTreeRepository.getTrees/getMemories` and `ScanGroupService.fetchGroupPreviews`. They **do not import, copy, relocate, or duplicate** media files, memories, albums, or scan records into Media Studio. Creation/edit/deletion continues in each existing module.
- **Direct album navigation**: `FamilyTreeDetailScreen(treeId, initialTabIndex: 2, initialMemoryId: ...)` opens the existing album detail. On desktop, the native right-side Life Archive inspector is used; on phone, it opens the existing full-page memory detail. Photo grid, full-screen photo viewer, edit, delete and linked events remain available.
- **Responsive navigation**: On desktop the linked library list stays in Media Studio's content area, while individual album/document records open in full-width routes for proper editing and inspection.
- **Refresh**: Linked overview loads on entry and refreshes after returning from linked records. The searchable library also refreshes after closing an album/document.

## Important

This ZIP contains the same **source-only Dart tree** supplied by the user; it does not contain the full Flutter root (`pubspec.yaml`, platform folders, assets). No new pub package was introduced. Run `flutter analyze`, app tests and device/browser acceptance tests after copying into the complete DayArk project. The included source-level QA suite passes.

## Manual acceptance checklist

1. Change DayArk theme and brightness from **Settings → Appearance**; verify Life Archive, memory detail, event detail and form sheets follow automatically. Confirm the archive has no separate Appearance control.
2. From **Media Studio → Connected libraries**, open **Memory albums**. Search, open an album, view photos, full-screen zoom/gallery, edit a memory and return. Confirm the changes appear back in Media and in the original Life Archive.
3. Open **Scanned documents**. Search, open a document, view/reorder/edit pages using existing scanner screens, and return. Confirm the original scanned document is unchanged unless explicitly edited.
4. On desktop, confirm the Media list is embedded and the selected Life Archive memory opens with its right-hand inspector. On phone, confirm it opens as a full-page preview.
5. Test no archives, no memories, no scans, missing thumbnails, offline storage, refresh, back navigation, and Android/iOS/desktop/web widths.
