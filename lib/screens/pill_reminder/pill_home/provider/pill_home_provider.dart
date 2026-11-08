import 'package:flutter_riverpod/legacy.dart';

import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import '../controller/pill_home_controller.dart';
import '../controller/pill_home_state.dart';

final pillHomeControllerProvider =
    StateNotifierProvider<PillHomeController, PillHomeState>(
  (ref) {
    final dbService = ref.read(databaseServiceProvider);
    final service = PillReminderService(dbService);
    return PillHomeController(service);
  },
);
