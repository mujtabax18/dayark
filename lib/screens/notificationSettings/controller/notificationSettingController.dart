// lib/providers/notification_settings_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/NotificationSettings.dart';
import '../../../services/NotificationService.dart';
import '../../../services/NotificationsManagers/QuoteNotificationManager.dart';
import '../../../services/database_service.dart';
import '../../../services/localDatabaseServices/notificationSettingService.dart';
import '../../Expenses/controller/ExpensesController.dart';

// final notificationServiceProvider = Provider<NotificationService>((ref) {
//   return NotificationService();
// });

// final quoteNotificationManagerProvider =
//     Provider<QuoteNotificationManager>((ref) {
//   final notificationService = ref.read(notificationServiceProvider);
//   return QuoteNotificationManager(ref, notificationService);
// });

// 1. First create databaseServiceProvider if not exists

// // 2. Service provider
// final notificationSettingServiceProvider =
//     Provider<NotificationSettingService>((ref) {
//   final databaseService = ref.read(databaseServiceProvider);
//   return NotificationSettingService(databaseService);
// });
//
// // 3. Improved individual feature settings provider
// final notificationSettingsProvider =
//     FutureProvider.family<NotificationSettings, String>(
//         (ref, featureName) async {
//   final service = ref.read(notificationSettingServiceProvider);
//   return await service.getSettingsOrDefault(featureName);
// });
//
// // Provider for all notification settings
// final allNotificationSettingsProvider =
//     FutureProvider<List<NotificationSettings>>((ref) async {
//   final service = ref.read(notificationSettingServiceProvider);
//   return await service.getAllNotificationSettings();
// });
//
// // Provider for active notification settings
// final activeNotificationSettingsProvider =
//     FutureProvider<List<NotificationSettings>>((ref) async {
//   final service = ref.read(notificationSettingServiceProvider);
//   return await service.getActiveNotificationSettings();
// });
