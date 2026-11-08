# DayArk: free multi-platform draft-release workflow

**Status:** Workflow and local script prepared and statically checked. **Flutter binaries have NOT been compiled/tested in the preparation environment.** Test a draft build before publication.

## 0. Security first — do not push the original ZIP

The full private archive provided for this setup contained real Android signing material in BOTH `android/` and `keys/`:

- `android/app/dayark-keystore.jks` and `keys/dayark-keystore.jks`
- `android/key.properties` and `keys/key.properties`
- `android/local.properties` and Gradle caches/build output

The **sanitized repository ZIP** removes those sensitive files, and its `.gitignore` excludes new ones. Copy the private keystore and properties back **locally only** to build the official Android APK. If any secret was previously committed to the PUBLIC repository (including old commits), it may already be exposed: review Git history, remove it with history rewriting if necessary, and evaluate credential/key rotation. **Changing an Android signing certificate can prevent upgrades of existing sideloaded installs**; preserve the original key securely and plan any rotation.

Security checks before pushing:

```bash
git status --short
git ls-files | grep -Ei '(^keys/|\.jks$|\.keystore$|(^|/)key\.properties$|(^|/)local\.properties$|^dist/|(^|/)build/)' || true
```

If secrets are already tracked, `git rm --cached ...` removes them from the current commit only, not earlier commits. For a *new repository*, it's easiest to start from the sanitized ZIP. For a repository with existing release history, plan a Git history cleanup separately; force-pushing a rewritten history affects everyone and requires coordination. GitHub's secret scanning/Push Protection can help, but it cannot replace the review.

## 1. Included files and version

- `.gitignore`: excludes Flutter and native build output, Linux AppImages, Windows installers, APK/AAB, caches, local properties and secrets.
- `.fvmrc`: Flutter **3.47.9**, matching the `>=3.47.0` constraint in `pubspec.yaml`. The original archive's 3.27.3 pin was incompatible.
- `pubspec.yaml`: `version: 0.0.39+39` (change for next release).
- `scripts/release.py`: **one Python entry point**, Linux and Windows compatible, optional Android APK, SHA256 files, optional draft upload.
- `.github/workflows/draft-release.yml`: manually triggered GitHub Actions workflow; packages Linux, Windows, optional Android; creates/updates a **draft only**.
- `android/app/build.gradle.kts`: requires signing material **only for Android release builds**; allows debug builds from public source.
- `android/key.properties.example`: dummy placeholder only; safe to commit.

**Do not rename** the internal Flutter package `metersystem`, Windows executable `metersystem.exe`, Android application ID `app.dayark.mobile.dev`, or Inno Setup AppId casually: upgrades and imports depend on these identities.

## 2. First-time GitHub setup — no paid service required

1. Back up your existing private project and signing files. Review [OPEN_SOURCE_READINESS.md](../OPEN_SOURCE_READINESS.md).
2. Make the existing GitHub repository `mujtabax18/dayark` public **only after** the source, history and bundled assets are safe, or publish the cleaned source in a new repo. The script defaults to `mujtabax18/dayark`; use `--repo OWNER/REPO` if different.
3. Add the sanitized source files and scripts, leaving ALL keys and generated build directories out of Git.
4. Confirm `LICENSE` and your rights to bundled files (including SVGs, icons, fonts, media, and copied snippets).
5. Commit and push to the default branch:

   ```bash
   git add .
   git status --short
   git commit -m "Open-source DayArk v0.0.39 and add draft release automation"
   git push origin main
   ```

   Adjust `main` if your default branch has another name. Check GitHub's **Files changed** view before committing.
6. Open GitHub repository **Settings → Actions → General**. Allow Actions, then under **Workflow permissions** permit **Read and write permissions** if needed by your repository policy. The workflow itself requests `contents: write` to create a draft and attach assets. Keep workflows restricted to trusted branches and maintainers.
7. Open the repository **Actions → Build DayArk draft release → Run workflow**. Select your branch, set `tag=v0.0.39`, choose `both`, `linux`, `windows` or `none`, and choose whether to build **Android** (off by default). Click **Run workflow**.
8. After the run, open **Releases → Drafts → v0.0.39**, confirm assets and checksums, download, test, and **publish manually when ready**.

The workflow runs **only when manually dispatched**. It does **not** trigger on push, a PR, or a published tag. The release is always created with `--draft`. Later Linux/Windows/Android jobs attach platform-specific assets to that same draft. It refuses to modify a published release.

GitHub-hosted standard Actions runners are free for **public repositories** under the current GitHub policy. Local Flutter builds and the GitHub CLI are also free. GitHub limits storage and has separate pricing for private repositories/larger runners; see the current official [Actions billing documentation](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Workflows and release artifacts may consume repository storage/traffic resources.

## 3. One script on Linux (CachyOS/other distros)

Prerequisites: supported Flutter SDK, Python 3.10+, Git, and Linux desktop build packages (`clang`, `cmake`, `ninja`, `pkg-config`, GTK3 headers, etc). For AppImage output, install `appimagetool` from the [official AppImage release page](https://github.com/AppImage/appimagetool/releases), give it execute permissions, and put it on `PATH` as `appimagetool`.

```bash
flutter doctor
flutter config --enable-linux-desktop
python3 scripts/release.py
```

The script **asks whether to build Android**, then builds Linux. It *optionally* asks whether to upload the built assets to a **draft** (default **No**). Files appear in `dist/v0.0.39/`:

- `DayArk-linux-x86_64.zip` (portable Flutter Linux bundle)
- `DayArk-x86_64.AppImage` and `DayArk-x86_64.AppImage.zsync` (if installed `appimagetool` produces them)
- `DayArk.apk` (only when Android is selected and signing is configured)
- `SHA256SUMS-linux.txt` and/or `SHA256SUMS-android.txt`

To force a fully unattended Linux + signed Android build and upload to a draft:

```bash
python3 scripts/release.py --platform linux --android yes --upload
```

To build locally only, without any upload prompt:

```bash
python3 scripts/release.py --platform linux --android no --no-upload
```

> **Important for in-app updates:** DayArk's Linux updater looks for a `.AppImage` asset, **not** the ZIP. Install `appimagetool` or use the GitHub Actions Linux job if you want Linux users to receive DayArk's in-app update prompt. The ZIP remains a portable/manual installation alternative.

## 4. One script on Windows

Prerequisites: [Flutter Windows desktop](https://docs.flutter.dev/platform-integration/windows/setup), Visual Studio C++ build tools, Python 3.10+, Git. Install [Inno Setup 6](https://jrsoftware.org/isinfo.php) for a `.exe` installer recognized by DayArk's in-app updater.

Open PowerShell in the source directory:

```powershell
flutter doctor
flutter config --enable-windows-desktop
py -3 scripts/release.py
```

The script builds Windows and asks if it should also build signed Android. The files appear in `dist/v0.0.39/`:

- `DayArk-windows-x64.zip` (portable Windows desktop app; unzip **the entire directory**, not just its `.exe`)
- `DayArk-Setup-windows-x64.exe` (if Inno Setup is installed)
- `DayArk.apk` (optional; with local private Android signing files)
- platform-specific SHA-256 checksum lists

Windows unattended:

```powershell
py -3 scripts/release.py --platform windows --android yes --upload
```

Without upload:

```powershell
py -3 scripts/release.py --platform windows --android no --no-upload
```

> **Important for in-app updates:** DayArk's Windows updater expects the Inno Setup `.exe`; the portable ZIP is for manual installs. Do not change the installer AppId while shipping updates.

## 5. Android signing: local machine only (recommended initially)

Your current `applicationId` and original signing key must remain consistent for sideloaded updates to install over prior DayArk versions.

1. Keep your **existing, original** `dayark-keystore.jks` somewhere secure, with an independent backup; do **not** generate a replacement for an existing installed app.
2. Copy it to `android/app/dayark-keystore.jks` for your local build. The repository ignores it.
3. Copy `android/key.properties.example` to `android/key.properties`, then fill in the real secrets **locally**. The repository ignores it.
4. Run `python3 scripts/release.py --platform android --android yes --no-upload` on Linux, or `py -3 scripts/release.py --platform android --android yes --no-upload` on Windows. You can also choose Android when prompted during a desktop build.
5. Verify `DayArk.apk` is signed by the correct certificate, then test upgrade-installation over an earlier release **without uninstalling**.

**Debug contributors do not need your keystore:** `flutter run` / debug builds work without `android/key.properties` after the included Gradle change.

### Optional: signed Android builds on GitHub Actions

For a fully automated Android draft job, GitHub needs two **encrypted Actions secrets** in **Settings → Secrets and variables → Actions**:

- `DAYARK_KEYSTORE_B64`: Base64 representation of the binary `android/app/dayark-keystore.jks`.
- `DAYARK_KEY_PROPERTIES_B64`: Base64 representation of your **private** `android/key.properties`.

On Linux, *after placing your secrets locally*, the CLI can set them without printing them:

```bash
base64 -w0 android/app/dayark-keystore.jks | gh secret set DAYARK_KEYSTORE_B64 --repo mujtabax18/dayark
base64 -w0 android/key.properties | gh secret set DAYARK_KEY_PROPERTIES_B64 --repo mujtabax18/dayark
```

On Windows PowerShell:

```powershell
$repo = 'mujtabax18/dayark'
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('android/app/dayark-keystore.jks'))
gh secret set DAYARK_KEYSTORE_B64 --repo $repo --body $b64
$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes('android/key.properties'))
gh secret set DAYARK_KEY_PROPERTIES_B64 --repo $repo --body $b64
Remove-Variable b64
```

**Base64 is encoding, not encryption.** Only put these values in GitHub **encrypted Actions secrets**, never source files, issue text, logs or unprotected variables. Keep the Android option **off** until you've reviewed signing security. In the workflow, the temporary files are recreated in the ephemeral runner and never committed. If you are not comfortable sharing signing keys with Actions, build Android only on your own machine and upload to the same draft using the local script.

## 6. Local draft upload using GitHub CLI

Install [GitHub CLI (`gh`)](https://cli.github.com/) first. On CachyOS / Arch Linux:

```bash
sudo pacman -S github-cli
gh auth login
gh auth status
```

On Windows PowerShell:

```powershell
winget install --id GitHub.cli --source winget
# Open a fresh terminal after installation
gh auth login
gh auth status
```

Commit and push your exact source first. For **each computer**, ensure the repository is clean and has the **same** `v0.0.39` source revision. From the project root:

```bash
# Linux
python3 scripts/release.py --platform linux --android no --upload

# Windows PowerShell
py -3 scripts/release.py --platform windows --android no --upload
```

The **first** run creates a DRAFT v0.0.39 targeted at the pushed source commit. The **second** uses that same draft and adds assets for the other platform. The script checks that your build's Git commit is pushed, that no known signing keys are tracked, and that the working tree is clean. It will **refuse to modify a published release**.

**Do not run `gh release create` without `--draft`.** Do not publish until all required OS packages are uploaded and tested. The in-app updater reads GitHub's `/releases/latest`, which ignores drafts.

Already-existing asset filenames cause a safe error rather than automatic replacement. If an old draft asset needs replacement, delete it manually from the draft and re-run; avoid `--clobber` unless you understand the risk of losing the old asset during an interrupted replacement.

## 7. Checks before clicking “Publish release”

```bash
flutter analyze
flutter test
```

Manually check upgrade data retention, backup/restore, LAN sync and devices. On GitHub, confirm the release has the expected names:

| Platform | Asset for in-app updates | Additional optional distribution |
|---|---|---|
| Android | `DayArk.apk` | SHA-256 checksum |
| Linux x64 | `DayArk-x86_64.AppImage` | `DayArk-linux-x86_64.zip`, `.zsync`, checksum |
| Windows x64 | `DayArk-Setup-windows-x64.exe` | `DayArk-windows-x64.zip`, checksum |

For the next release, change `pubspec.yaml` version and build number, amend `.github/workflows/draft-release.yml` default tag, create the matching `GITHUB_RELEASE_vX.Y.Z.md` notes if desired, then commit/push. Run the same workflow with the new tag.

### Important limitations

- Flutter/Dart and all native toolchains were unavailable in the environment preparing these files; **the actual platform builds and GitHub run have not been executed here**.
- The AppImage needs runtime testing across representative Linux distributions (glibc and libraries are not universally portable).
- Windows installers are unsigned unless you configure code-signing separately, so SmartScreen may warn.
- Android GitHub Actions requires your own signing secrets. Never share them with pull requests from forks.
- No iOS/macOS release automation is included. Building signed Apple apps requires an Apple-hosted toolchain and separate signing/provisioning.
- GitHub Actions runner minutes are currently free for public repositories using standard runners; check current billing rules before running large builds or enabling advanced runners.
