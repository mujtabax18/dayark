"""Source-level regression checks for panel navigation and gallery-first UX.

These guard the wiring in the delivered source-only ZIP; Flutter widget and
platform tests are still necessary in the full DayArk project.
Run: python qa/test_life_archive_inspector.py
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1] / 'screens' / 'family_tree' / 'view'


def file(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class TestInspector(unittest.TestCase):
    def test_inspector_is_embedded_not_full_route(self):
        state = file('parts/family_tree_detail_screen_state.dart')
        event = file('parts/family_tree_detail_screen_life.dart')
        panel = file('life_archive_inspector_panel.dart')
        self.assertIn('await _selectInspector(memoryId: memory.id)', state)
        self.assertIn('await _selectInspector(eventId: event.id)', event)
        self.assertIn('LifeArchiveInspectorPanel(', state)
        self.assertIn('width: available >= 1250 ? 490 : 445,', state)
        self.assertIn('Positioned.fill(', state)
        self.assertIn('final inspector = inspectorVisible', state)
        self.assertNotIn('Navigator.of(', panel)
        self.assertNotIn('showModalBottomSheet', panel)
        self.assertNotIn('PageView', panel)

    def test_album_click_opens_detail_gallery(self):
        source = file('parts/family_tree_detail_screen_tree_tab.dart')
        pages = file('life_archive_detail_pages.dart')
        panel = file('life_archive_inspector_panel.dart')
        self.assertIn('onTap: () => widget.onTap(memory)', source)
        self.assertNotIn('widget.onPhotoTap(valid, 0, memory.title)', source)
        self.assertIn('SliverGrid.builder(', pages)
        self.assertIn('SliverGrid.builder(', panel)
        self.assertIn('onViewPhoto(photos, index, current.title)', panel)
        self.assertIn('onSelectMemory(album)', panel)
        self.assertIn('onTap: () => onMemoryTap(memory)', pages)

    def test_panel_actions_theme_and_navigation_history(self):
        state = file('parts/family_tree_detail_screen_state.dart')
        panel = file('life_archive_inspector_panel.dart')
        self.assertIn('List<({int? memoryId, int? eventId})>', state)
        self.assertIn('onBack: _inspectorHistory.isEmpty ? null : _backInspector', state)
        self.assertIn('onEdit: () async {', state)
        self.assertIn('onDelete: () async {', state)
        self.assertIn('onAddMemory: () async {', state)
        self.assertIn('onSelectEvent: (event) =>', state)
        self.assertIn('await _showMemoryForm(memory: selectedMemory)', state)
        self.assertIn('await _showLifeEventForm(event: selectedEvent)', state)
        self.assertIn('LifeArchiveDesktop.enabled(constraints)', state)
        self.assertNotIn('_effectiveArchiveTheme', state)
        self.assertIn('_inspectorGraphSuspended', state)
        self.assertIn('ArchiveDesktopSidebar(', state)
        self.assertIn('CustomScrollView(', panel)
        self.assertIn('SafeArea(', panel)
        self.assertIn('onClose', panel)

    def test_all_relative_imports_resolve(self):
        paths = [
            'family_tree_detail_screen.dart',
            'life_archive_detail_pages.dart',
            'life_archive_desktop_detail_pages.dart',
            'life_archive_inspector_panel.dart',
            'parts/family_tree_detail_screen_state.dart',
            'parts/family_tree_detail_screen_life.dart',
            'parts/family_tree_detail_screen_tree_tab.dart',
        ]
        for name in paths:
            path = ROOT / name
            self.assertTrue(path.is_file(), name)
            for uri in re.findall(r"^(?:import|part|part of)\s+['\"]([^'\"]+)['\"]", path.read_text(), re.M):
                if uri.startswith(('dart:', 'package:')):
                    continue
                self.assertTrue((path.parent / uri).exists(), f'{name}: {uri}')


if __name__ == '__main__':
    unittest.main()
