import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../models/HomeFeatureModel.dart';
import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/HomeFeaturesService.dart';

final counterProvider = StateProvider<int>((ref) => 0);

class HomeProvider extends StateNotifier<List<HomeFeatureModel>> {
  HomeProvider(this.ref) : super([]) {
    _featureService = HomeFeatureService(ref.read(databaseServiceProvider));
    loadFeatures();
  }

  final Ref ref;
  late final HomeFeatureService _featureService;

  Future<void> loadFeatures() async {
    try {
      final features = await _featureService.getFeatures();
      final sortedFeatures = [...features]
        ..sort((a, b) => a.position.compareTo(b.position));
      state = sortedFeatures;
    } catch (_) {
      if (state.isEmpty) {
        state = [...HomeFeatureModel.defaultFeatures]
          ..sort((a, b) => a.position.compareTo(b.position));
      }
    }
  }

  Future<void> updateFeaturePositions(
    List<HomeFeatureModel> updatedList,
  ) async {
    final normalized = <HomeFeatureModel>[
      for (var index = 0; index < updatedList.length; index++)
        updatedList[index].copyWith(position: index),
    ];
    state = normalized;
    await _featureService.updateFeaturePositions(normalized);
  }
}

final homeProvider =
    StateNotifierProvider<HomeProvider, List<HomeFeatureModel>>(
  HomeProvider.new,
);
