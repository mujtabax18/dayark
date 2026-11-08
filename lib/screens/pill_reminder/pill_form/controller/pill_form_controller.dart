import 'package:flutter_riverpod/legacy.dart';
import 'package:metersystem/screens/pill_reminder/pill_form/controller/pillformstate.dart';

import '../../../../services/localDatabaseServices/PillReminder_Service.dart';

class PillFormController extends StateNotifier<PillFormState> {
  PillFormController(this._service) : super(PillFormState()) {
    loadMeta();
  }

  final PillReminderService _service;

  Future<void> loadMeta() async {
    try {
      final pillTypes = await _service.getPillTypes();
      final dosageTypes = await _service.getDosageTypes();
      state = state.copyWith(pillTypes: pillTypes, dosageTypes: dosageTypes);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<Map<String, dynamic>?> loadEditMeta(int pillId) async {
    try {
      return {
        'rule': await _service.getActiveScheduleRule(pillId),
        'inventory': await _service.getPillInventory(pillId),
      };
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<void> addPill({
    required String name,
    required double dosageValue,
    required double doseQuantity,
    required int dosageTypeId,
    required int pillTypeId,
    required String colorHex,
    required String notes,
    required String startDate,
    String? endDate,
    required bool trackInventory,
    required double initialQuantity,
    int lowInventoryAlertAt = 5,
    required String ruleType,
    required List<String> times,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    int? intervalDays,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _service.createFullPill(
        name: name,
        dosageValue: dosageValue,
        doseQuantity: doseQuantity,
        dosageTypeId: dosageTypeId,
        pillTypeId: pillTypeId,
        colorHex: colorHex,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        trackInventory: trackInventory,
        initialQuantity: initialQuantity,
        lowInventoryAlertAt: lowInventoryAlertAt,
        ruleType: ruleType,
        times: times,
        daysOfWeek: daysOfWeek,
        daysOfMonth: daysOfMonth,
        intervalDays: intervalDays,
      );
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updatePill({
    required int pillId,
    required String name,
    required double dosageValue,
    required double doseQuantity,
    required int dosageTypeId,
    required int pillTypeId,
    required String colorHex,
    required String notes,
    required String startDate,
    String? endDate,
    required bool trackInventory,
    int lowInventoryAlertAt = 5,
    required String ruleType,
    required List<String> times,
    List<int>? daysOfWeek,
    List<int>? daysOfMonth,
    int? intervalDays,
  }) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      await _service.editPill(
        pillId: pillId,
        name: name,
        dosageValue: dosageValue,
        doseQuantity: doseQuantity,
        dosageTypeId: dosageTypeId,
        pillTypeId: pillTypeId,
        colorHex: colorHex,
        notes: notes,
        startDate: startDate,
        endDate: endDate,
        trackInventory: trackInventory,
        lowInventoryAlertAt: lowInventoryAlertAt,
        ruleType: ruleType,
        times: times,
        daysOfWeek: daysOfWeek,
        daysOfMonth: daysOfMonth,
        intervalDays: intervalDays,
      );
      state = state.copyWith(isSaving: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }
}
