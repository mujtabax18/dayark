> **Historical note (7 November 2026):** The separate archive Appearance selector described below was removed. Life Archive now follows the single global DayArk theme configured in Settings → Appearance. See `screens/Multimedia/MEDIA_ARCHIVE_SCANNER_INTEGRATION.md` for current behavior.

# Life Archives — full-page previews, photo gallery and appearance

## Included

- Memory preview is a dedicated full-screen Flutter route, with title, date, story, tagged people, linked event, responsive photo grid, Edit and Delete.
- Event preview is a dedicated full-screen Flutter route, with header, date, location, description, people and linked album previews. Edit/Delete/Add memory remain connected to the existing repositories.
- Memories tab offers **Albums** and **Photos** gallery views. An album image opens the photo viewer; its caption opens the memory detail page. The Photos grid opens the entire archive's photo library for swiping.
- Photos open full-screen with horizontal swiping and pinch-to-zoom; invalid local file paths are skipped.
- Life Archive AppBar palette icon opens a full-screen appearance selector: Follow app, System, Light, Dark, and App default/Indigo/Emerald/Ocean/Sunset/Rose color presets.
- The selected appearance is stored via existing shared_preferences per archive ID and is applied to archive tabs, album/event pages, and edit form contents. Existing application-wide theme preferences are unchanged.
- Full-screen routes suspend the underlying Linux/Windows native WebView using the existing graph snapshot mechanism. Graph orbit/view state is preserved when the route is dismissed.

## Important scope note

This archive contains only the application's Dart source (the uploaded archive did not include pubspec.yaml or the bundled HTML graph asset). The embedded starfield HTML visualization keeps its original cinematic rendering; the new appearance setting affects the Flutter UI around it. No additional packages are needed beyond the app's existing Flutter, intl, Riverpod and shared_preferences dependencies.

## Suggested manual regression checks

1. Open a Life Archive > Memories > Albums. Tap an image: photo opens full-screen and swipes/zooms. Back returns to Albums. Tap album title: full-page detail opens.
2. Switch to Photos; verify images from different albums appear and can be swiped in the viewer.
3. Open an event from Events and from a node in the Network graph. Verify full page, related people/memories, and navigation back.
4. From a memory/event page, Edit, Save and Delete; verify confirmation, reloading, cancellation, and no stale preview.
5. Change mode and palette, exit/reopen the archive; verify persistence and no change to the global DayArk theme. Test both system brightness values.
6. On Linux/Windows, open preview and image routes while the native WebView is active, then return and confirm orbit/zoom is preserved and no WebView overlays appear above routes/forms.
7. Check phone, tablet and desktop grid widths; check text-only albums and albums with missing photos.

**Build note:** A Flutter SDK and full pubspec/assets are not available in this editing environment, so `flutter analyze`/runtime tests could not be executed here. Run them in the full app project before release.
