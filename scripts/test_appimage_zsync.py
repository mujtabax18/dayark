#!/usr/bin/env python3
"""Offline integration checks for AppImage/zsync output paths, using fake tools."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'packaging/linux/build-appimage.sh'

class AppImageMetadataTests(unittest.TestCase):
    def build(self, automatic: bool):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / 'project'
            packaging = root / 'packaging/linux'
            packaging.mkdir(parents=True)
            shutil.copy2(SOURCE, packaging / 'build-appimage.sh')
            (packaging / 'dayark.desktop').write_text('[Desktop Entry]\nName=DayArk\n')
            (packaging / 'dayark.png').write_bytes(b'png')
            (packaging / 'AppRun').write_text('#!/bin/sh\n')
            bin_dir = Path(temp) / 'bin'
            bin_dir.mkdir()
            flutter = bin_dir / 'flutter'
            flutter.write_text('''#!/bin/sh
set -eu
mkdir -p "$TEST_ROOT/build/linux/x64/release/bundle"
printf elf > "$TEST_ROOT/build/linux/x64/release/bundle/metersystem"
''')
            appimagetool = bin_dir / 'appimagetool'
            appimagetool.write_text('''#!/bin/sh
set -eu
for arg do destination="$arg"; done
printf appimage > "$destination"
if [ "${CREATE_ZSYNC_AUTOMATICALLY:-no}" = yes ]; then
  printf 'zsync: 0.6\\nURL: DayArk-x86_64.AppImage\\n\\n' > "$destination.zsync"
fi
''')
            zsync = bin_dir / 'zsyncmake'
            zsync.write_text('''#!/bin/sh
set -eu
printf '%s\\n' "$@" > "$TEST_ROOT/zsync-invocation.txt"
while [ "$#" -gt 0 ]; do
  if [ "$1" = '-o' ]; then shift; output="$1"; fi
  shift
done
printf 'zsync: 0.6\\nURL: DayArk-x86_64.AppImage\\n\\n' > "$output"
''')
            for path in (flutter, appimagetool, zsync):
                path.chmod(0o755)
            env = os.environ.copy()
            env['PATH'] = str(bin_dir) + os.pathsep + env['PATH']
            env['TEST_ROOT'] = str(root)
            env['CREATE_ZSYNC_AUTOMATICALLY'] = 'yes' if automatic else 'no'
            result = subprocess.run(['bash', str(packaging / 'build-appimage.sh')],
                                    cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((root / 'dist/DayArk-x86_64.AppImage').read_bytes(), b'appimage')
            self.assertIn(b'URL: DayArk-x86_64.AppImage',
                          (root / 'dist/DayArk-x86_64.AppImage.zsync').read_bytes())
            self.assertFalse((root / 'DayArk-x86_64.AppImage.zsync').exists())
            self.assertEqual((root / 'zsync-invocation.txt').exists(), not automatic)

    def test_appimagetool_generates_zsync_inside_dist(self):
        self.build(automatic=True)

    def test_fallback_creates_missing_zsync_inside_dist(self):
        self.build(automatic=False)

if __name__ == '__main__':
    unittest.main()
