import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import '../controller/PillSettingsState.dart';
import '../controller/pill_settings_controller.dart';

final pillSettingsControllerProvider =
    StateNotifierProvider<PillSettingsController, PillSettingsState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final service = PillReminderService(dbService);
  return PillSettingsController(service);
});
