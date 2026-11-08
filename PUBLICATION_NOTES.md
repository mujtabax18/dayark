# Prepared public repository — what changed and what to do next

This source tree was prepared from the maintainer-supplied complete Flutter project archive for DayArk v0.0.39. **It has not yet been uploaded or published to GitHub.**

## Security-sensitive files intentionally omitted

- `android/app/dayark-keystore.jks`
- `android/key.properties`
- `keys/dayark-keystore.jks`
- `keys/key.properties`
- `android/local.properties`
- Cached/generated native build output and stale generated plugin registrants.

**Do not copy those keys into Git.** Retain private copies for official signed Android upgrades. If they ever appeared in a public commit, inspect and clean history too.

## Code/configuration changes

- Updated `pubspec.yaml` to 0.0.39+39 and `.fvmrc` to Flutter 3.47.9.
- Updated root `.gitignore` and Android `.gitignore` to keep build outputs and keys out while retaining the Gradle wrapper.
- Android Gradle debug builds no longer require the maintainer's keystore. Release builds require it.
- Added a single cross-platform `scripts/release.py` and offline tests in `scripts/test_release.py`.
- Added the manually triggered workflow `.github/workflows/draft-release.yml`.
- Added `docs/RELEASE_AUTOMATION.md` and updated README/contributor/release docs.
- Removed unused old Life Archive appearance screen.
- Fixed `lib/qa/test_life_constellation.cjs` relative asset path.
- Replaced broken generated counter example in `test/widget_test.dart` with a release metadata smoke test.

## What was tested

Source-only Python QA checks passed; graph JavaScript fixture passed; offline release script tests passed; YAML structure parsed. **Flutter compilation, Android signing, and GitHub Actions execution were not performed** because the necessary toolchains/credentials and GitHub permissions were unavailable here. Review and test real binaries before publishing.

## Publish safely

Read [docs/RELEASE_AUTOMATION.md](docs/RELEASE_AUTOMATION.md) for CachyOS, Windows, Android, draft release steps, Actions pricing notes, and secret-handling instructions. Verify files with `git status --short` and `git ls-files` before pushing. Only press **Publish release** after downloading and testing each draft artifact.
