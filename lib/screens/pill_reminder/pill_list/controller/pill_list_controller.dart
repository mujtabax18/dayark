import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:metersystem/screens/pill_reminder/pill_list/controller/pill_list_state.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';

class PillListController extends StateNotifier<PillListState> {
  final PillReminderService _service;

  PillListController(this._service) : super(PillListState()) {
    loadPills();
  }

  Future<void> loadPills() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pills = await _service.getPillsWithInventoryAll();
      state = state.copyWith(pills: pills, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> deactivatePill(int pillId) async {
    await _service.deletePill(pillId);
    await loadPills();
  }

  Future<void> restorePill(int pillId) async {
    await _service.undoDeletePill(pillId);
    await loadPills();
  }

  Future<bool> permanentlyDeletePill(int pillId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.permanentlyDeletePill(pillId);
      await loadPills();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> refillInventory(int pillId, double qty) async {
    try {
      await _service.refillInventory(
        pillId: pillId,
        addQuantity: qty,
      );
      await loadPills();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
