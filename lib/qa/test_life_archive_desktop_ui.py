"""Static regression contract for the Life Archives responsive UI source files.

Run: python qa/test_life_archive_desktop_ui.py
This is not a replacement for flutter analyze or real widget/platform tests.
"""
from pathlib import Path
import re
import unittest

LIB = Path(__file__).resolve().parents[1]
VIEW = LIB / 'screens' / 'family_tree' / 'view'


class TestLifeArchiveDesktopSource(unittest.TestCase):
    def test_source_files_and_local_imports_exist(self):
        names = [
            'family_tree_home_screen.dart', 'family_tree_detail_screen.dart',
            'life_archive_detail_pages.dart', 'life_archive_desktop_detail_pages.dart',
            'life_archive_desktop_widgets.dart', 'life_archive_media.dart',
            'family_photo_gallery.dart',
            'parts/family_tree_detail_screen_state.dart',
            'parts/family_tree_detail_screen_tree_tab.dart',
            'parts/family_tree_detail_screen_life.dart',
        ]
        for name in names:
            path = VIEW / name
            self.assertTrue(path.is_file(), name)
            body = path.read_text()
            for uri in re.findall(r"^(?:import|part|part of)\s+['\"]([^'\"]+)['\"]", body, re.M):
                if uri.startswith(('dart:', 'package:')):
                    continue
                self.assertTrue((path.parent / uri).exists(), f'{name}: {uri}')

    def test_desktop_navigation_and_search_filters(self):
        home = (VIEW / 'family_tree_home_screen.dart').read_text()
        state = (VIEW / 'parts/family_tree_detail_screen_state.dart').read_text()
        memories = (VIEW / 'parts/family_tree_detail_screen_tree_tab.dart').read_text()
        events = (VIEW / 'parts/family_tree_detail_screen_life.dart').read_text()
        for field in ['ArchiveDesktopSidebar(', 'ArchiveDesktopHeader(',
                      'ArchiveDesktopStat(', 'Search archives', 'New archive']:
            self.assertIn(field, home)
        for field in ['ArchiveDesktopSidebar(', "'Network'", "'People'",
                      "'Memories'", "'Events'"]:
            self.assertIn(field, state)
        for field in ['Search memories', "'newest'", "'oldest'", "'title'",
                      'onPhotoTap']:
            self.assertIn(field, memories)
        for field in ['Search events or locations', 'All event types',
                      'Newest first', '_buildTable(', '_buildCards(']:
            self.assertIn(field, events)

    def test_full_page_previews_and_web_image_guard(self):
        pages = (VIEW / 'life_archive_detail_pages.dart').read_text()
        desktop = (VIEW / 'life_archive_desktop_detail_pages.dart').read_text()
        gallery = (VIEW / 'family_photo_gallery.dart').read_text()
        media = (VIEW / 'life_archive_media.dart').read_text()
        self.assertIn('_DesktopMemoryDetail(page: this)', pages)
        self.assertIn('_DesktopEventDetail(page: this)', pages)
        self.assertIn("part of 'life_archive_detail_pages.dart'", desktop)
        self.assertIn('showFullscreenFamilyPhotos(', desktop)
        self.assertIn('InteractiveViewer(', gallery)
        self.assertIn('if (kIsWeb) return false', media)
        self.assertIn('LifeArchiveMedia.canDisplay', gallery)


if __name__ == '__main__':
    unittest.main()
