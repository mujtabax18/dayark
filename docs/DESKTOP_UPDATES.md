> **New for v0.0.39:** For a single Linux/Windows/Android build script and GitHub draft-release workflow, see [RELEASE_AUTOMATION.md](RELEASE_AUTOMATION.md). The manual steps below remain useful for platform troubleshooting.

# DayArk updates: Android, Windows and Linux

This implementation extends the existing DayArk update dialog. GitHub Releases is the single public update feed:
https://github.com/mujtabax18/dayark/releases/latest

## What changed in Flutter

- `lib/services/app_update/app_update_service.dart`: checks stable GitHub releases on Android, Windows and Linux, chooses the matching package, shows download progress, verifies the size and SHA-256 digest *when GitHub provides one*, and hands off installation to the OS-specific installer.
- `lib/services/app_update/app_update_dialog.dart`: retains the existing dialog; users click **Download & install**. Android opens the APK confirmation; Windows opens the Inno Setup wizard; Linux asks user to close DayArk and reopens the updated AppImage.
- `lib/services/app_update/app_update_coordinator.dart`: permits the existing startup and Settings checks on desktop.
- `lib/screens/Settings/view/backupScreen.dart`: changes the Settings subtitle to mention every supported OS.

The project version is still read from `pubspec.yaml` through `package_info_plus`. Keep the GitHub tag in sync.

## One-time setup for Windows

1. On a **Windows x64** computer install Flutter desktop prerequisites and [Inno Setup 6](https://jrsoftware.org/isinfo.php).
2. Run this from the Flutter project directory:

   ```powershell
   flutter config --enable-windows-desktop
   .\packaging\windows\build-installer.ps1
   ```

3. Upload `dist/DayArk-Setup-windows-x64.exe` to your GitHub release.
4. New users download this installer and install DayArk normally. Existing installed users receive the updater dialog after a later release.

**Important**: Do not change `AppId` in `packaging/windows/dayark.iss`. The installer keeps the original installation directory and replaces the installed program, not user-data folders. Flutter's Windows executable is currently named `metersystem.exe`; this is intentional and is what the installer bundles. Avoid publishing a portable ZIP as the update asset. Optional: sign the installer (recommended to reduce Windows SmartScreen warnings).

The installer is interactive: after downloading, DayArk opens Setup. Setup can prompt the user to close a running application, and it will not restart the Windows operating system without consent. Windows UAC depends on installation permissions and other publisher security policies.

## One-time setup for Linux

1. On a **Linux x86_64** computer with the required Flutter GTK build dependencies, obtain `appimagetool` from the [official AppImageKit releases](https://github.com/AppImage/AppImageKit/releases), mark it executable, and put it on your PATH as `appimagetool`.
2. Run:

   ```bash
   flutter config --enable-linux-desktop
   bash packaging/linux/build-appimage.sh
   ```

3. Verify these exist:

   ```text
   dist/DayArk-x86_64.AppImage
   dist/DayArk-x86_64.AppImage.zsync
   ```

4. Upload **both** to the same GitHub release. New users can download `DayArk-x86_64.AppImage`, put it in a user-writable location such as `~/Applications/`, and run:

   ```bash
   chmod +x ~/Applications/DayArk-x86_64.AppImage
   ~/Applications/DayArk-x86_64.AppImage
   ```

5. When an update appears, DayArk downloads the new **complete** AppImage, checks the download, and launches a small detached shell helper. After the user presses **Close & install update**, the helper safely replaces the AppImage and starts DayArk again. No `sudo` is required for a file the user owns.

**Important**: Linux in-app replacement currently supports the **x86_64 AppImage format only**. It does **not** modify Flutter ZIP bundles, AUR/pacman, `.deb`, Flatpak, Snap or system-owned/read-only locations. For those distribution types, updates must be delivered through their package manager. Do not store the AppImage in `/usr/bin` or another root-owned location if you want in-app updates. On Linux distributions requiring libfuse2, install the runtime dependency for launching type 2 AppImages.

### What does the `.zsync` file do?

`appimagetool --updateinformation "zsync|..."` embeds a pointer to the stable `.zsync` URL in the AppImage. That lets third-party tools such as `appimageupdatetool` perform optional **delta** updates. The current DayArk Flutter updater deliberately downloads the **full** AppImage to avoid requiring users to install or bundle additional AppImageUpdate tools. It still creates the `.zsync` file for future use and external tools. Upload it, but don't assume the in-app downloads are delta updates.

## Create a GitHub Release

For example, change your `pubspec.yaml` from:

```yaml
version: 0.0.37+37
```

to:

```yaml
version: 0.0.38+38
```

Then build Android APK, Windows installer and Linux AppImage from the **same version**. Create a **published, non-prerelease** GitHub release with tag `v0.0.38` and attach all assets:

```text
v0.0.38
  app-release.apk                      # OR any DayArk*.apk naming
  DayArk-Setup-windows-x64.exe
  DayArk-x86_64.AppImage
  DayArk-x86_64.AppImage.zsync
```

The release Notes become the update dialog's **What's new** text.

The auto-check occurs when DayArk starts; users can also check manually from **Settings → App Updates → Check for updates**. If a release has no installer for the current OS, the manual check explains which package is missing.

## Test safely before public release

1. Build/install `v0.0.38` on each target operating system and verify database files, documents, media and app preferences are preserved. **Back up test data first.**
2. Change to `0.0.39+39`, rebuild, and publish `v0.0.39` with all three matching assets.
3. Start `v0.0.38`. Confirm the dialog displays `0.0.38 → 0.0.39` and accurate release notes.
4. Click **Download & install**. Confirm download progress, installer launch, user confirmation, app restart on Linux, and retained user data.
5. Test the `Later` action, disabled startup checks, no network, unwriteable Linux AppImage location, failed download and mismatched SHA-256.
6. Test Windows specifically **on Windows**, Linux AppImage **on Linux**, and APK **on Android**. Do not substitute `flutter run` for testing the Linux updater: it requires the `APPIMAGE` runtime environment variable.

## Security and production notes

- The updater uses HTTPS and validates the published SHA-256 digest when the GitHub Release API supplies `asset.digest`. Check that your published assets provide this field; signing installer/AppImage releases is recommended for a public app.
- Do not publish debug binaries, install a differently named Windows executable, change Windows `AppId`, or relocate stored user data as part of an app update.
- The Linux detached helper is generated from code shipped *inside DayArk*, not downloaded from the internet. It only replaces the AppImage file, not the database.
- **No SDK or native build validation was possible in this environment**: the patch should be integrated into the full local project, with assets (omitted from your uploaded archive), then compiled and tested on target operating systems.
