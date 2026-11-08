import 'package:flutter_riverpod/legacy.dart';
import 'package:metersystem/screens/scanner/controllers/provideers/scanGroupRepoProvider.dart';
import 'package:metersystem/screens/scanner/controllers/provideers/scannerRepoProvider.dart';

import '../ScanGroupViewController.dart';
import '../states/ScanGroupViewState.dart';

final scanGroupViewControllerProvider = StateNotifierProvider.family<
    ScanGroupViewController, ScanGroupViewState, int>((ref, groupId) {
  return ScanGroupViewController(
    ref,
    ref.watch(scannerServiceProvider),
    ref.watch(scanGroupServiceProvider),
    groupId,
  );
});
