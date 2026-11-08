# DayArk open-source and build-readiness review

**Date:** 8 November 2026  
**Source reviewed:** `Archive(8).zip` — complete Flutter application archive supplied by the maintainer  
**Target:** proposed `v0.0.39` open-source transition, still **unpublished**

## What the current archive contains

The newer archive contains source and platform projects (`lib`, `pubspec.yaml`, `pubspec.lock`, `assets`, Android, iOS, Linux, Windows, macOS, web), test files and existing packaging scripts. This corrects the older `Archive(7).zip` review, which only examined a partial Dart source snapshot.

**Important:** The complete project structure is present, but **no platform binary was built** in this inspection environment because Flutter/Android Studio/desktop toolchains were unavailable here. This is a source review, not a reproducible-build or penetration-test certification.

## Critical security discovery

The supplied private archive contains Android keystores and passwords in `android/app`, `android` and `keys`. These are **not safe to publish**. The sanitized ZIP excludes the keys and signing properties, supplies a `key.properties.example`, and uses `.gitignore` to protect future local builds.

- Before publishing, inspect the existing public repository's **full Git history**. Removing a current file does not erase its history.
- Retain the current Android signing identity for users who must upgrade the sideloaded app without uninstalling. Protect the signing key in secure, backed-up offline storage and use GitHub Secrets only if you choose cloud-signed APKs.
- Treat every third-party icon, audio clip, font or copied component as subject to license review.
- No complete automated search can prove that all credentials and personal data are absent; review manually and use secret scanning.

## Build setup improvements in this sanitized copy

- Bumped `pubspec.yaml` from `0.0.38+38` to `0.0.39+39`.
- Updated `.fvmrc` from incompatible Flutter `3.27.3` to compatible `3.47.9`.
- Updated `.gitignore`: excludes Linux/Windows release output, Android APK/AAB, local build caches, Android signing secrets, env files and generated platform output.
- Changed Android Gradle signing to **permit debug builds without private keystore** and **require a private keystore for release tasks**.
- Added a cross-platform build/package/draft-upload script (`scripts/release.py`).
- Added a manually triggered GitHub Actions draft release workflow for Linux, Windows and optional signed Android.
- Prepared `docs/RELEASE_AUTOMATION.md` with repeatable local and GitHub setup instructions.
- Removed an unused Life Archive appearance screen no active module referenced, bringing a source regression check into compliance.
- Fixed source-level JavaScript graph test's relative path for the newly supplied HTML asset.
- Replaced the obsolete generated Flutter counter example test with a source metadata smoke test (runtime verification still pending).

## Checks performed during preparation

| Check | Result | What it proves |
| --- | --- | --- |
| Four supplied Python QA scripts | **PASS** (12 cases/scenarios total) | Selected source contracts and SQLite schema fixtures |
| `node lib/qa/test_life_constellation.cjs` | **PASS** | JS graph fixture with the actual bundled HTML |
| `python scripts/release.py --dry-run --android yes` | **PASS** | Python CLI argument parsing, version, and plan |
| Python compile and GitHub YAML parse | **PASS** | Source-level syntax checks only |
| Full `flutter pub get`, `flutter analyze`, `flutter test` | **NOT RUN** | Flutter SDK unavailable in the inspection environment |
| Linux AppImage and Windows Inno installer | **NOT BUILT** | Must build on target platforms before release |
| Android signed APK | **NOT BUILT** | Private keys intentionally excluded from public copy |
| GitHub Actions run or GitHub draft upload | **NOT RUN** | Requires repository access and user's approval |

## Still recommended before publishing

1. Review `LICENSE` and third-party licenses, source assets, old commits and branches for private information.
2. Restore signing files to your **private local project only** when testing Android release builds.
3. Run `flutter pub get`, `flutter analyze`, `flutter test`, then compile release builds on Linux, Windows and Android.
4. Test backup/restore, existing-record migrations, cross-device LAN sync, and v0.0.38 → v0.0.39 upgrade **without uninstalling**.
5. Test the installer filenames recognized by the in-app updater: `.AppImage`, `DayArk-Setup-windows-x64.exe`, and `DayArk.apk`. Portable ZIPs do not trigger native update/install flows.
6. Test Linux AppImage on representative distributions, Windows installer on a clean machine, and Android APK signing identity.
7. Check GitHub Actions permissions and secret availability. Review the **draft** assets and digests before manually publishing.

See [the release automation guide](docs/RELEASE_AUTOMATION.md), [contributor guide](CONTRIBUTING.md), and [release checklist](RELEASE_CHECKLIST.md).
