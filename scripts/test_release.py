#!/usr/bin/env python3
"""Small offline regression tests for release.py (no Flutter/GitHub access)."""
import tempfile
import unittest
from pathlib import Path
from unittest import mock
import zipfile

import release


class ReleaseScriptTests(unittest.TestCase):
    def test_version_comes_from_real_pubspec(self):
        self.assertEqual(release.get_version(), '0.0.39')

    def test_zip_contains_full_bundle_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)
            (p/'bundle'/'data').mkdir(parents=True)
            (p/'bundle'/'app').write_bytes(b'compiled executable')
            (p/'bundle'/'data'/'assets').write_bytes(b'asset')
            out=p/'dist'/'app.zip'
            release.zip_directory(p/'bundle',out)
            with zipfile.ZipFile(out) as z:
                self.assertEqual(set(z.namelist()), {'DayArk/app', 'DayArk/data/assets'})
                self.assertEqual(z.read('DayArk/app'), b'compiled executable')

    def test_checksum_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)
            source=p/'DayArk.apk';source.write_bytes(b'demo')
            result=release.write_checksum([source],p/'SHA256SUMS-android.txt').read_text()
            self.assertEqual(result, release.checksum(source)+'  DayArk.apk\n')

    def test_android_release_requires_private_properties(self):
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(release,'ROOT',Path(tmp)):
            with self.assertRaisesRegex(RuntimeError,'Missing private'):
                release.check_android_signing()

    def test_upload_refuses_published_release(self):
        with mock.patch.object(release,'require_tool'), \
             mock.patch.object(release,'ensure_clean_pushed_checkout',return_value='abcdef0123'), \
             mock.patch.object(release,'run'), \
             mock.patch.object(release.subprocess,'run') as sprun:
            sprun.return_value.returncode=0
            sprun.return_value.stdout='false\n'
            with self.assertRaisesRegex(RuntimeError,'already PUBLISHED'):
                release.upload_draft('v0.0.39','mujtabax18/dayark',[],'0.0.39')

    def test_linux_bundle_without_appimagetool(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            (root/'build/linux/x64/release/bundle').mkdir(parents=True)
            (root/'build/linux/x64/release/bundle/metersystem').write_bytes(b'executable')
            with mock.patch.object(release,'ROOT',root), \
                 mock.patch.object(release.platform,'system',return_value='Linux'), \
                 mock.patch.object(release.platform,'machine',return_value='x86_64'), \
                 mock.patch.object(release.shutil,'which',return_value=None), \
                 mock.patch.object(release,'run') as build:
                files=release.build_linux(root/'dist/v0.0.39', '0.0.39')
                self.assertEqual([p.name for p in files], ['DayArk-linux-x86_64.zip'])
                self.assertTrue(files[0].is_file())
                build.assert_called_once_with('flutter','build','linux','--release')


if __name__=='__main__':
    unittest.main()
