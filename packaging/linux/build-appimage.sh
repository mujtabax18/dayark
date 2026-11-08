#!/usr/bin/env bash
# Build DayArk's Linux AppImage and zsync metadata into the same dist/ folder.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo 'ERROR: Flutter SDK is not on PATH.' >&2; exit 1
fi
if ! command -v appimagetool >/dev/null 2>&1; then
  echo 'ERROR: Install appimagetool and add it to PATH.' >&2; exit 1
fi
if ! command -v zsyncmake >/dev/null 2>&1; then
  echo 'ERROR: Install zsync (provides zsyncmake).' >&2; exit 1
fi
if [[ "$(uname -m)" != 'x86_64' ]]; then
  echo 'ERROR: This packaging script supports Linux x86_64 only.' >&2; exit 1
fi

flutter build linux --release
APPDIR="$ROOT/build/dayark.AppDir"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
[[ -f "$BUNDLE/metersystem" ]] || {
  echo "ERROR: Flutter Linux binary not found: $BUNDLE/metersystem" >&2
  exit 1
}

rm -rf -- "$APPDIR"
mkdir -p "$APPDIR/usr/bin/dayark" "$APPDIR/usr/share/applications"
cp -a "$BUNDLE/." "$APPDIR/usr/bin/dayark/"
cp "$ROOT/packaging/linux/dayark.desktop" "$APPDIR/dayark.desktop"
cp "$ROOT/packaging/linux/dayark.desktop" "$APPDIR/usr/share/applications/dayark.desktop"
cp "$ROOT/packaging/linux/dayark.png" "$APPDIR/dayark.png"
cp "$ROOT/packaging/linux/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"

DIST="$ROOT/dist"
APPIMAGE_NAME='DayArk-x86_64.AppImage'
APPIMAGE="$DIST/$APPIMAGE_NAME"
ZSYNC="$APPIMAGE.zsync"
mkdir -p "$DIST"
rm -f -- "$APPIMAGE" "$ZSYNC"

# GitHub /latest/download will resolve only after the release is PUBLISHED.
# Stable asset names allow the same embedded URL across all published versions.
UPDATE_URL="zsync|https://github.com/mujtabax18/dayark/releases/latest/download/$APPIMAGE_NAME.zsync"

# IMPORTANT: zsyncmake writes the .zsync output to the CURRENT WORKING DIRECTORY.
# appimagetool may call zsyncmake itself, so invoke it FROM dist/ rather than
# from the project root. Giving the AppImage its basename is intentional.
(
  cd "$DIST"
  ARCH=x86_64 appimagetool --updateinformation "$UPDATE_URL" "$APPDIR" "$APPIMAGE_NAME"
)
[[ -s "$APPIMAGE" ]] || { echo 'ERROR: appimagetool did not create an AppImage' >&2; exit 1; }
chmod +x "$APPIMAGE"

# Different appimagetool builds can skip automatic .zsync generation. Generate
# it explicitly as a reliable fallback, with the expected relative download URL.
if [[ ! -s "$ZSYNC" ]]; then
  echo 'appimagetool did not generate .zsync; running zsyncmake explicitly...'
  zsyncmake -u "$APPIMAGE_NAME" -o "$ZSYNC" "$APPIMAGE"
fi

[[ -s "$ZSYNC" ]] || { echo "ERROR: .zsync missing after explicit generation: $ZSYNC" >&2; exit 1; }
if ! grep -aqF "URL: $APPIMAGE_NAME" "$ZSYNC"; then
  echo "ERROR: .zsync metadata does not reference $APPIMAGE_NAME" >&2
  exit 1
fi

printf '\nSUCCESS: Linux release outputs:\n%s\n%s\n' "$APPIMAGE" "$ZSYNC"
echo 'Both files will be attached to the existing GitHub DRAFT by scripts/release.py.'
