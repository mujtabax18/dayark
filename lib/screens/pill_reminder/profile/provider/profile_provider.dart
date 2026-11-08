import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import '../../../notificationSettings/controller/notificationSettingController.dart';
import '../controller/profile_controller.dart';
import '../controller/profile_stat.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final pillService = PillReminderService(dbService);
  return ProfileController(pillService);
});
