// import 'package:flutter/material.dart';
// import '../../models/NotificationSettings.dart';
// import '../localDatabaseServices/NotificationLogService.dart';
// import '../localDatabaseServices/notificationSettingService.dart';
// import 'QuoteNotificationManager.dart';
//
// class NotificationChecker {
//   final NotificationSettingService _settingService;
//   final NotificationLogService _logService;
//   final QuoteNotificationManager
//       _quoteNotificationManager; // Inject QuoteNotificationManager
//
//   late Map<String, Function(NotificationSettings)> _notificationHandlers = {};
//
//   NotificationChecker(
//       this._settingService, this._logService, this._quoteNotificationManager) {
//     // Initialize default handlers
//     _notificationHandlers = {
//       'mood_tracker': _triggerMoodTrackerNotification,
//       'medication_reminder': _triggerMedicationReminder,
//       'therapy_session': _triggerTherapySessionReminder,
//       'quotes': _triggerQouteReminder,
//     };
//   }
//
//   /// Register a custom notification handler
//   void registerHandler(
//       String featureName, Function(NotificationSettings) handler) {
//     _notificationHandlers[featureName] = handler;
//   }
//
//   Future<void> checkAndTriggerNotifications() async {
//     try {
//       debugPrint('[NotificationChecker] Starting notification check');
//       final activeSettings =
//           await _settingService.getActiveNotificationSettings();
//       final now = DateTime.now();
//
//       for (final setting in activeSettings) {
//         if (await _shouldSendNotification(setting, now)) {
//           await _triggerNotification(setting);
//           await _logService.recordNotificationSent(setting.id!);
//           debugPrint('[NotificationChecker] Triggered ${setting.featureName}');
//         }
//       }
//     } catch (e, stackTrace) {
//       debugPrint('[NotificationChecker] Error: $e\n$stackTrace');
//       rethrow;
//     }
//   }
//
//   Future<bool> _shouldSendNotification(
//       NotificationSettings setting, DateTime now) async {
//     // Check if notification is active
//     if (!setting.isActive) {
//       debugPrint('[NotificationChecker] ${setting.featureName} is inactive');
//       return false;
//     }
//
//     // Check time window
//     if (!_isWithinTimeWindow(setting, now)) {
//       debugPrint(
//           '[NotificationChecker] ${setting.featureName} outside time window');
//       return false;
//     }
//
//     // Check blocked periods
//     if (_isBlockedPeriod(setting, now)) {
//       debugPrint(
//           '[NotificationChecker] ${setting.featureName} in blocked period');
//       return false;
//     }
//
//     // Check notification interval
//     return await _isDueForNotification(setting, now);
//   }
//
//   bool _isWithinTimeWindow(NotificationSettings setting, DateTime now) {
//     if (setting.startTime == null || setting.endTime == null) return true;
//
//     final currentTime = TimeOfDay.fromDateTime(now);
//     final start = setting.startTime!;
//     final end = setting.endTime!;
//
//     if (start.hour > end.hour) {
//       // Overnight window (e.g., 10 PM to 6 AM)
//       return currentTime.hour >= start.hour || currentTime.hour <= end.hour;
//     } else {
//       // Normal daytime window
//       return currentTime.hour >= start.hour && currentTime.hour <= end.hour;
//     }
//   }
//
//   bool _isBlockedPeriod(NotificationSettings setting, DateTime now) {
//     return setting.blockedDays.contains(now.weekday) ||
//         setting.blockedDates.contains(now.day) ||
//         setting.blockedMonths.contains(now.month);
//   }
//
//   Future<bool> _isDueForNotification(
//       NotificationSettings setting, DateTime now) async {
//     final lastSent = await _logService.getLastSentTime(setting.id!);
//     if (lastSent == null) return true;
//
//     final nextTime = _calculateNextNotificationTime(setting, lastSent);
//     final isDue = now.isAfter(nextTime);
//     // final isDue = true;
//
//     if (!isDue) {
//       debugPrint(
//           '[NotificationChecker] ${setting.featureName} not due until $nextTime');
//     }
//     return isDue;
//   }
//
//   DateTime _calculateNextNotificationTime(
//       NotificationSettings setting, DateTime lastSent) {
//     switch (setting.intervalType) {
//       case 'minutes':
//         return lastSent.add(Duration(minutes: setting.intervalValue));
//       case 'hours':
//         return lastSent.add(Duration(hours: setting.intervalValue));
//       case 'days':
//         return lastSent.add(Duration(days: setting.intervalValue));
//       case 'weeks':
//         return lastSent.add(Duration(days: setting.intervalValue * 7));
//       case 'months':
//         return DateTime(
//           lastSent.year,
//           lastSent.month + setting.intervalValue,
//           lastSent.day,
//           lastSent.hour,
//           lastSent.minute,
//         );
//       case 'years':
//         return DateTime(
//           lastSent.year + setting.intervalValue,
//           lastSent.month,
//           lastSent.day,
//           lastSent.hour,
//           lastSent.minute,
//         );
//       default:
//         return lastSent.add(Duration(days: setting.intervalValue));
//     }
//   }
//
//   Future<void> _triggerNotification(NotificationSettings setting) async {
//     final handler = _notificationHandlers[setting.featureName];
//     if (handler == null) {
//       debugPrint('[NotificationChecker] No handler for ${setting.featureName}');
//       return;
//     }
//
//     try {
//       await handler(setting);
//     } catch (e, stackTrace) {
//       debugPrint(
//           '[NotificationChecker] Error in ${setting.featureName} handler: $e\n$stackTrace');
//       rethrow;
//     }
//   }
//
//   // Default notification handlers (can be overridden with registerHandler)
//   Future<void> _triggerMoodTrackerNotification(
//       NotificationSettings setting) async {
//     debugPrint('Would trigger mood tracker notification');
//     // Implement your actual notification logic here
//   }
//
//   Future<void> _triggerMedicationReminder(NotificationSettings setting) async {
//     debugPrint('Would trigger medication reminder');
//     // Implement your actual notification logic here
//   }
//
//   Future<void> _triggerQouteReminder(NotificationSettings setting) async {
//     debugPrint('Would trigger medication reminder');
//     await _quoteNotificationManager.sendRandomQuoteNotification();
//
//     // Implement your actual notification logic here
//   }
//
//   Future<void> _triggerTherapySessionReminder(
//       NotificationSettings setting) async {
//     debugPrint('Would trigger therapy session reminder');
//     // Implement your actual notification logic here
//   }
//
//   Future<void> resetNotificationHistory(int settingId) async {
//     await _logService.clearLogsForSetting(settingId);
//   }
//
//   Future<int> getNotificationCount(int settingId,
//       {Duration? withinDuration}) async {
//     return await _logService.getNotificationCount(
//       settingId,
//       withinDuration: withinDuration,
//     );
//   }
// }
