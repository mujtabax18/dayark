import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:metersystem/screens/pill_reminder/profile/controller/profile_stat.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';

class ProfileController extends StateNotifier<ProfileState> {
  final PillReminderService _service;

  ProfileController(this._service) : super(ProfileState()) {
    loadProfiles();
  }

  Future<void> loadProfiles() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profiles = await _service.getAllProfiles();
      state = state.copyWith(profiles: profiles, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> addProfile(String name) async {
    await _service.createProfile(name);
    await loadProfiles();
  }

  Future<void> updateProfile(int id, String name) async {
    await _service.updateProfile(id, {'name': name});
    await loadProfiles();
  }

  Future<void> deleteProfile(int id) async {
    await _service.deleteProfile(id);
    await loadProfiles();
  }

  Future<void> setActiveProfile(int id) async {
    await _service.setActiveProfile(id);
    await loadProfiles();
  }
}
