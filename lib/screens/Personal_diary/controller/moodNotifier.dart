import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:metersystem/models/moodTrackerModel.dart';
import 'package:metersystem/services/database_service.dart';
import 'package:metersystem/services/localDatabaseServices/moodtracker.dart';

class MoodNotifier extends StateNotifier<List<MoodEntry>> {
  MoodNotifier(this.databaseService) : super(const []) {
    loadMoodHistory();
  }

  final DatabaseService databaseService;
  bool _loading = false;

  Future<void> loadMoodHistory() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await MoodtrackerSerive(databaseService).fetchMoodHistory();
      state = _sorted(data);
    } finally {
      _loading = false;
    }
  }

  Future<MoodEntry> addOrUpdateMood(MoodEntry entry) async {
    final savedEntry = await MoodtrackerSerive(databaseService)
        .insertOrUpdateMood(entry);

    if (entry.id == null) {
      state = _sorted([savedEntry, ...state]);
    } else {
      state = _sorted(
        state.map((item) => item.id == savedEntry.id ? savedEntry : item),
      );
    }
    return savedEntry;
  }

  Future<void> toggleFavorite(int id) async {
    MoodEntry? entry;
    for (final item in state) {
      if (item.id == id) {
        entry = item;
        break;
      }
    }
    if (entry == null) return;
    await addOrUpdateMood(entry.copyWith(isFavorite: !entry.isFavorite));
  }

  Future<MoodEntry?> entryById(int id) async {
    for (final item in state) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> deleteMood(int id) async {
    await MoodtrackerSerive(databaseService).deleteMood(id);
    state = state.where((entry) => entry.id != id).toList(growable: false);
  }

  static List<MoodEntry> _sorted(Iterable<MoodEntry> entries) {
    final result = entries.toList();
    result.sort((left, right) {
      final byDate = right.entryDateTime.compareTo(left.entryDateTime);
      if (byDate != 0) return byDate;
      return (right.id ?? 0).compareTo(left.id ?? 0);
    });
    return result;
  }
}

final moodProvider = StateNotifierProvider<MoodNotifier, List<MoodEntry>>(
  (ref) => MoodNotifier(ref.watch(databaseServiceProvider)),
);

final moodEditProvider = StateProvider<MoodEntry?>((ref) => null);
