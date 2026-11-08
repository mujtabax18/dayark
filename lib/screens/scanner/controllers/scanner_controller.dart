import 'dart:io';

import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';

import '../data/models/scan_group_model.dart';
import '../data/repo/scan_group_service.dart';
import '../data/repo/scanner_repo.dart';
import 'states/ScannerState.dart';

class ScannerController extends StateNotifier<ScannerState> {
  ScannerController(
    this._scannerService,
    this._groupService,
  ) : super(const ScannerState()) {
    loadScans();
  }

  final ScannerService _scannerService;
  final ScanGroupService _groupService;

  Future<int> createGroup({
    String? title,
    String source = 'scanner',
  }) async {
    final now = DateTime.now();
    final cleaned = title?.trim();
    return _groupService.createGroup(
      ScanGroup(
        title: cleaned == null || cleaned.isEmpty
            ? 'Scanned document ${DateFormat('dd MMM yyyy, h:mm a').format(now)}'
            : cleaned,
        source: source,
        createdAt: now.toIso8601String(),
        updatedAt: now.toIso8601String(),
      ),
    );
  }

  Future<int?> addMultipleScans({
    required List<String> paths,
    int? groupId,
    String? title,
    String source = 'scanner',
  }) async {
    if (paths.isEmpty) return null;
    state = state.copyWith(isLoading: true);
    try {
      final targetGroupId = groupId ??
          await createGroup(
            title: title,
            source: source,
          );
      await _scannerService.importScans(
        paths.map(File.new),
        groupId: targetGroupId,
      );
      await loadScans();
      state = state.copyWith(activeGroupId: targetGroupId);
      return targetGroupId;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadScans() async {
    state = state.copyWith(isLoading: true);
    try {
      final scans = await _scannerService.fetchAllScans();
      state = state.copyWith(scans: scans, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}
