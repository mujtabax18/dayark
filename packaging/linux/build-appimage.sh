#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is not on PATH.' >&2; exit 1
fi
if ! command -v appimagetool >/dev/null 2>&1; then
  echo 'Install appimagetool and add it to PATH (see docs/DESKTOP_UPDATES.md).' >&2; exit 1
fi
if [[ "$(uname -m)" != 'x86_64' ]]; then
  echo 'This build script currently supports Linux x86_64 only.' >&2; exit 1
fi
flutter build linux --release
APPDIR="$ROOT/build/dayark.AppDir"
BUNDLE="$ROOT/build/linux/x64/release/bundle"
[[ -f "$BUNDLE/metersystem" ]] || { echo "Build missing: $BUNDLE/metersystem" >&2; exit 1; }
rm -rf -- "$APPDIR"
mkdir -p "$APPDIR/usr/bin/dayark" "$APPDIR/usr/share/applications"
cp -a "$BUNDLE/." "$APPDIR/usr/bin/dayark/"
cp "$ROOT/packaging/linux/dayark.desktop" "$APPDIR/dayark.desktop"
cp "$ROOT/packaging/linux/dayark.desktop" "$APPDIR/usr/share/applications/dayark.desktop"
cp "$ROOT/packaging/linux/dayark.png" "$APPDIR/dayark.png"
cp "$ROOT/packaging/linux/AppRun" "$APPDIR/AppRun"
chmod +x "$APPDIR/AppRun"
mkdir -p "$ROOT/dist"
# Same asset names for every tag allow GitHub /latest/download URLs.
UPDATE_URL="zsync|https://github.com/mujtabax18/dayark/releases/latest/download/DayArk-x86_64.AppImage.zsync"
ARCH=x86_64 appimagetool --updateinformation "$UPDATE_URL" \
  "$APPDIR" "$ROOT/dist/DayArk-x86_64.AppImage"
chmod +x "$ROOT/dist/DayArk-x86_64.AppImage"
echo 'Upload dist/DayArk-x86_64.AppImage and dist/DayArk-x86_64.AppImage.zsync to your GitHub release.'
