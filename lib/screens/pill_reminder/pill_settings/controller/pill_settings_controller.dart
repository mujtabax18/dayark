import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import 'PillSettingsState.dart';

class PillSettingsController extends StateNotifier<PillSettingsState> {
  final PillReminderService _service;

  PillSettingsController(this._service) : super(PillSettingsState()) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pillTypes = await _service.getPillTypes();
      final dosageTypes = await _service.getDosageTypes();
      state = state.copyWith(
        pillTypes: pillTypes,
        dosageTypes: dosageTypes,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  // ---------- PILL TYPE ----------
  Future<void> addPillType(String name) async {
    await _service.createPillType(name);
    await loadAll();
  }

  Future<void> updatePillType(int id, String name) async {
    await _service.updatePillType(id, name);
    await loadAll();
  }

  Future<void> deletePillType(int id) async {
    await _service.deletePillType(id);
    await loadAll();
  }

  // ---------- DOSAGE TYPE ----------
  Future<void> addDosageType(String name) async {
    await _service.createDosageType(name);
    await loadAll();
  }

  Future<void> updateDosageType(int id, String name) async {
    await _service.updateDosageType(id, name);
    await loadAll();
  }

  Future<void> deleteDosageType(int id) async {
    await _service.deleteDosageType(id);
    await loadAll();
  }
}
