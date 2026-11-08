import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/MonthClosing.dart';
import '../services/database_service.dart';
import '../services/localDatabaseServices/monthClosing.dart';

final monthClosingRepositoryProvider = Provider<MonthClosingHelper>((ref) {
  return MonthClosingHelper(ref.watch(databaseServiceProvider));
});

class MonthClosingController extends AsyncNotifier<List<MonthClosing>> {
  MonthClosingHelper get _repository =>
      ref.read(monthClosingRepositoryProvider);

  @override
  Future<List<MonthClosing>> build() => _repository.getAllClosings();

  Future<ClosingPreview> preview({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _repository.previewClosing(
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<MonthClosing> closeMonth({
    required String title,
    String description = '',
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final result = await _repository.closeMonth(
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
    );
    ref.invalidateSelf();
    await future;
    return result;
  }

  Future<void> reopenClosing(int id) async {
    await _repository.reopenClosing(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> refreshClosings() async {
    ref.invalidateSelf();
    await future;
  }
}

final monthClosingControllerProvider =
    AsyncNotifierProvider<MonthClosingController, List<MonthClosing>>(
  MonthClosingController.new,
);
