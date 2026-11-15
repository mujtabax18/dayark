"""Static regression checks for archive and media-sync integration.
Run with python -m unittest discover -s lib/qa -p test_life_archive_sync_contract.py.
These checks do not replace Flutter analysis or two-device integration tests.
"""
from pathlib import Path
import unittest

LIB=Path(__file__).resolve().parents[1]
SYNC=(LIB/'services/device_sync/parts/device_sync_service_device_sync_service.dart').read_text()
REPO=(LIB/'screens/family_tree/services/family_tree_repository.dart').read_text()

class LifeArchiveSyncContract(unittest.TestCase):
    def test_sibling_group_writes(self):
        for marker in ['pending.addAll(siblings[current]', 'entry.value.containsAll(parents)',
                       "await writeLink(ids[i], ids[j], 'sibling')", 'hasPath(ids[i], ids[j])',
                       'if (shareParentsWithSiblings)']:
            self.assertIn(marker,REPO)

    def test_media_pull_is_authenticated_and_verified(self):
        handler=SYNC[SYNC.index('Future<void> _serveSyncMedia'):SYNC.index('Future<File> _syncMediaTarget')]
        for marker in ["device_id=? AND revoked=0", 'previous_token', '_peerNeedsBootstrap',
                       '_syncMediaColumns[table]', 'i.entity_id=?', '_ownedMediaFile',
                       'x-dayark-media-sha256', 'sha256.bind']:
            self.assertIn(marker,handler)
        self.assertIn('sha256.bind(temp.openRead())',SYNC)
        self.assertIn('received != response.contentLength',SYNC)
        self.assertIn('rows.first[column] != oldPath',SYNC)
        self.assertIn('await temp.rename(target.path)',SYNC)
        self.assertIn('if (supportsMedia) await _pullMissingMedia(peer)',SYNC)
        for table in ['family_members','family_member_photos','family_memories','family_memory_photos','family_trees']:
            self.assertIn(f"'{table}': [",SYNC)

    def test_remote_paths_and_archive_refresh(self):
        self.assertIn('await _localizeMediaPaths(table, entityId',SYNC)
        self.assertIn("'DayArkSyncedMedia'",SYNC)
        self.assertIn('SyncContentSignal.notify()',SYNC)
        for file in ['family_tree_home_screen.dart','parts/family_tree_detail_screen_state.dart']:
            src=(LIB/'screens/family_tree/view'/file).read_text()
            self.assertIn('SyncContentSignal.revision.addListener',src)
            self.assertIn('SyncContentSignal.revision.removeListener',src)

if __name__=='__main__':unittest.main()
