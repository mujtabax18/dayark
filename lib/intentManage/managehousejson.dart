import '../services/restoreService.dart';

Future<void> manageHouseJson(String filePath) async {
  await DatabaseRestoreService.extractDataFromFile();
}
