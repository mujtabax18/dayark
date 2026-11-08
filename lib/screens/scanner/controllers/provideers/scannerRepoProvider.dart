import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../services/database_service.dart';
import '../../data/repo/scanner_repo.dart';
import '../scanner_controller.dart';
import '../states/ScannerState.dart';
import 'scanGroupRepoProvider.dart';

final scannerServiceProvider = Provider<ScannerService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  final storage = ref.watch(scanStorageServiceProvider);
  return ScannerService(dbService, storageService: storage);
});

final scannerControllerProvider =
    StateNotifierProvider<ScannerController, ScannerState>((ref) {
  final scannerService = ref.watch(scannerServiceProvider);
  final groupService = ref.watch(scanGroupServiceProvider);
  return ScannerController(scannerService, groupService);
});
