import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import '../controller/pill_form_controller.dart';
import '../controller/pillformstate.dart';

final pillFormControllerProvider =
    StateNotifierProvider<PillFormController, PillFormState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  final service = PillReminderService(dbService);
  return PillFormController(service);
});
