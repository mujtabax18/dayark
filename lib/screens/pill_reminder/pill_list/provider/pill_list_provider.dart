import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../services/database_service.dart';
import '../../../../services/localDatabaseServices/PillReminder_Service.dart';
import '../controller/pill_list_controller.dart';

import '../controller/pill_list_state.dart';

final pillListControllerProvider =
    StateNotifierProvider<PillListController, PillListState>((ref) {
  final dbService = ref.read(databaseServiceProvider);
  return PillListController(PillReminderService(dbService));
});
