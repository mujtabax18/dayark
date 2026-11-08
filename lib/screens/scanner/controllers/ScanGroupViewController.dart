import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../data/models/scan_model.dart';
import '../data/repo/scan_group_service.dart';
import '../data/repo/scanner_repo.dart';
import 'provideers/scanGroupRepoProvider.dart';
import 'states/ScanGroupViewState.dart';

class ScanGroupViewController extends StateNotifier<ScanGroupViewState> {
  ScanGroupViewController(
    this.ref,
    this._scannerService,
    this._groupService,
    this.groupId,
  ) : super(const ScanGroupViewState()) {
    load();
  }

  final ScannerService _scannerService;
  final ScanGroupService _groupService;
  final int groupId;
  final Ref ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final scans = await _scannerService.fetchAllScans(groupId: groupId);
      final group = await _groupService.fetchGroup(groupId);
      state = state.copyWith(
        title: group?.title ?? 'Scanned document',
        scans: scans,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> renameGroup(String newTitle) async {
    final cleaned = newTitle.trim();
    if (cleaned.isEmpty) return;
    final group = await _groupService.fetchGroup(groupId);
    if (group == null) return;
    await _groupService.updateGroup(group.copyWith(title: cleaned));
    state = state.copyWith(title: cleaned);
    _refreshPreviews();
  }

  Future<void> toggleGroupFavorite() async {
    await _groupService.toggleFavorite(groupId);
    _refreshPreviews();
  }

  Future<void> deleteGroup() async {
    await _groupService.deleteGroupWithScans(groupId);
    _refreshPreviews();
  }

  Future<void> addScans(List<String> paths) async {
    if (paths.isEmpty) return;
    await _scannerService.importScans(
      paths.map(File.new),
      groupId: groupId,
    );
    await load();
    _refreshPreviews();
  }

  Future<void> deleteScan(int scanId) async {
    final updated = [...state.scans]..removeWhere((entry) => entry.id == scanId);
    state = state.copyWith(scans: updated);
    await _scannerService.deleteScan(scanId);
    await _scannerService.updateScanOrder(groupId, updated);
    _refreshPreviews();
  }

  Future<void> duplicateScan(ScanEntry scan) async {
    await _scannerService.duplicateScan(scan);
    await load();
    _refreshPreviews();
  }

  Future<void> reorderLocallyAndPersist({
    required int oldIndex,
    required int newIndex,
  }) async {
    final scans = [...state.scans];
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= scans.length) return;
    if (newIndex < 0 || newIndex >= scans.length) return;
    final moved = scans.removeAt(oldIndex);
    scans.insert(newIndex, moved);
    state = state.copyWith(scans: scans);
    try {
      await _scannerService.updateScanOrder(groupId, scans);
      _refreshPreviews();
    } catch (error) {
      debugPrint('Reorder failed: $error');
      await load();
    }
  }

  void enableSelectionMode([bool enable = true]) {
    state = state.copyWith(
      selectionMode: enable,
      selectedIds: const {},
    );
  }

  void toggleSelection(int scanId) {
    final updated = Set<int>.from(state.selectedIds);
    updated.contains(scanId) ? updated.remove(scanId) : updated.add(scanId);
    state = state.copyWith(selectedIds: updated);
  }

  void selectAll() {
    state = state.copyWith(
      selectionMode: true,
      selectedIds: state.scans.map((entry) => entry.id).whereType<int>().toSet(),
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectionMode: false,
      selectedIds: const {},
    );
  }

  List<ScanEntry> get selectedScans => state.scans
      .where((entry) => state.selectedIds.contains(entry.id))
      .toList(growable: false);

  Future<void> deleteSelectedScans() async {
    final selected = Set<int>.from(state.selectedIds);
    final remaining = state.scans
        .where((entry) => entry.id == null || !selected.contains(entry.id))
        .toList(growable: false);
    for (final id in selected) {
      await _scannerService.deleteScan(id);
    }
    await _scannerService.updateScanOrder(groupId, remaining);
    state = state.copyWith(
      scans: remaining,
      selectedIds: const {},
      selectionMode: false,
    );
    _refreshPreviews();
  }

  Future<void> duplicateSelectedScans() async {
    final scans = selectedScans;
    for (final scan in scans) {
      await _scannerService.duplicateScan(scan);
    }
    clearSelection();
    await load();
    _refreshPreviews();
  }

  void _refreshPreviews() {
    ref.invalidate(scanGroupPreviewProvider);
    ref.invalidate(filteredScanGroupPreviewProvider);
  }
}
