"""Source-only regression checks for shared theme and Media Studio links.

Run in the original full Flutter project with flutter analyze and widget tests
before shipping; these assertions specifically guard the integration contract.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / 'screens/family_tree/view'
MEDIA = ROOT / 'screens/Multimedia'


def source(path):
    return path.read_text(encoding='utf-8')


class TestMediaArchiveLinks(unittest.TestCase):
    def test_archive_follows_app_theme(self):
        state = source(ARCHIVE / 'parts/family_tree_detail_screen_state.dart')
        host = source(ARCHIVE / 'family_tree_detail_screen.dart')
        self.assertNotIn('SharedPreferences', host)
        self.assertNotIn('_archiveMode', state)
        self.assertNotIn('_archivePreset', state)
        self.assertNotIn('_effectiveArchiveTheme', state)
        self.assertNotIn('_showAppearancePage', state)
        self.assertNotIn('LifeArchiveAppearancePage', host)
        self.assertFalse((ARCHIVE / 'life_archive_appearance_page.dart').exists())
        self.assertIn('builder: builder,', state)

    def test_media_opens_original_records(self):
        bridge = source(MEDIA / 'media_linked_libraries.dart')
        dashboard = source(MEDIA / 'parts/multimedia_dashboard_state.dart')
        archive = source(ARCHIVE / 'parts/family_tree_detail_screen_state.dart')
        self.assertIn('_archives.getMemories(archive.id)', bridge)
        self.assertIn('_scanGroups.fetchGroupPreviews()', bridge)
        self.assertIn('FamilyTreeDetailScreen(', bridge)
        self.assertIn('ScanGroupViewScreen(groupId: document.id)', bridge)
        self.assertIn('initialMemoryId: album.memory.id', dashboard)
        self.assertIn('initialTabIndex: 2', dashboard)
        self.assertIn('if (mounted) _showMemoryDetails(memory)', archive)
        self.assertIn('await _selectInspector(memoryId: memory.id)', archive)
        self.assertIn('MediaLinkedOverviewSection(', dashboard)
        self.assertIn('MediaLinkedSection.documents', dashboard)
        self.assertIn('MediaLinkedSection.memories', dashboard)
        self.assertNotIn('createMemory(', bridge)
        self.assertNotIn('createGroup(', bridge)

    def test_imports_exist_in_edited_modules(self):
        for path in [
            ARCHIVE / 'family_tree_detail_screen.dart',
            ARCHIVE / 'parts/family_tree_detail_screen_state.dart',
            MEDIA / 'MultimediaDashboard.dart',
            MEDIA / 'parts/multimedia_dashboard_state.dart',
            MEDIA / 'media_linked_libraries.dart',
        ]:
            body = source(path)
            for uri in re.findall(r"^(?:import|part|part of)\s+['\"]([^'\"]+)['\"]", body, re.M):
                if uri.startswith(('dart:', 'package:')):
                    continue
                self.assertTrue((path.parent / uri).is_file(), f'{path}: {uri}')


if __name__ == '__main__':
    unittest.main()
