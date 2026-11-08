// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
//
// import '../../main.dart';
// import '../../services/NotificationsManagers/QuoteNotificationManager.dart';
// import '../../services/NotificationsManagers/notificationCheckerClass.dart';
// import '../../services/localDatabaseServices/NotificationLogService.dart';
// import '../../services/localDatabaseServices/notificationSettingService.dart';
// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
//
// class ForegroundServiceWidget extends StatefulWidget {
//   final NotificationSettingService settingService;
//   final NotificationLogService logService;
//   final QuoteNotificationManager
//       quoteNotificationManager; // Receive QuoteNotificationManager
//
//   const ForegroundServiceWidget({
//     super.key,
//     required this.settingService,
//     required this.logService,
//     required this.quoteNotificationManager, // Add to constructor
//   });
//
//   @override
//   State<ForegroundServiceWidget> createState() =>
//       _ForegroundServiceWidgetState();
// }
//
// class _ForegroundServiceWidgetState extends State<ForegroundServiceWidget> {
//   late final NotificationChecker _notificationChecker;
//
//   Timer? _checkTimer;
//   bool _isServiceRunning = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _notificationChecker = NotificationChecker(
//       widget.settingService,
//       widget.logService,
//       widget.quoteNotificationManager, // Pass QuoteNotificationManager
//     );
//     _initServiceState();
//   }
//
//   Future<void> _initServiceState() async {
//     final isRunning = await FlutterForegroundTask.isRunningService;
//     setState(() {
//       _isServiceRunning = isRunning;
//     });
//     if (isRunning) {
//       _startHourlyChecks();
//     }
//   }
//
//   Future<void> _requestPermissions() async {
//     final NotificationPermission notificationPermission =
//         await FlutterForegroundTask.checkNotificationPermission();
//     if (notificationPermission != NotificationPermission.granted) {
//       await FlutterForegroundTask.requestNotificationPermission();
//     }
//
//     if (Platform.isAndroid) {
//       if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
//         await FlutterForegroundTask.requestIgnoreBatteryOptimization();
//       }
//
//       if (!await FlutterForegroundTask.canScheduleExactAlarms) {
//         await FlutterForegroundTask.openAlarmsAndRemindersSettings();
//       }
//     }
//   }
//
//   void _initService() {
//     FlutterForegroundTask.init(
//       androidNotificationOptions: AndroidNotificationOptions(
//         channelId: 'notification_service',
//         channelName: 'Notification Service',
//         channelDescription: 'Running Local Notification Service ',
//         priority: NotificationPriority.HIGH,
//         onlyAlertOnce: true,
//       ),
//       iosNotificationOptions: const IOSNotificationOptions(
//         showNotification: false,
//         playSound: false,
//       ),
//       foregroundTaskOptions: ForegroundTaskOptions(
//         eventAction: ForegroundTaskEventAction.repeat(5000),
//         autoRunOnBoot: true,
//         autoRunOnMyPackageReplaced: true,
//         allowWakeLock: true,
//         allowWifiLock: true,
//       ),
//     );
//   }
//
//   void _startHourlyChecks() {
//     // Initial check
//     _notificationChecker.checkAndTriggerNotifications();
//     // Set up periodic checks
//     _checkTimer = Timer.periodic(const Duration(hours: 1), (_) {
//       _notificationChecker.checkAndTriggerNotifications();
//     });
//   }
//
//   void _stopHourlyChecks() {
//     _checkTimer?.cancel();
//     _checkTimer = null;
//   }
//
//   Future<void> _toggleService() async {
//     await _requestPermissions();
//     _initService();
//
//     if (_isServiceRunning) {
//       await FlutterForegroundTask.stopService();
//       _stopHourlyChecks();
//     } else {
//       await FlutterForegroundTask.startService(
//         serviceId: 256,
//         notificationTitle: 'Notification Service',
//         notificationText: 'Running periodic checks',
//         callback: startCallback,
//       );
//       _startHourlyChecks();
//     }
//
//     final isRunning = await FlutterForegroundTask.isRunningService;
//     setState(() {
//       _isServiceRunning = isRunning;
//     });
//   }
//
//   @override
//   void dispose() {
//     _stopHourlyChecks();
//     FlutterForegroundTask.clearAllData();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       margin: const EdgeInsets.all(8.0),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Notification Service',
//                       style:
//                           TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//                     ),
//                     Text(
//                       'Checks notifications periodically',
//                       style: TextStyle(fontSize: 12, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//                 Switch(
//                   value: _isServiceRunning,
//                   onChanged: (value) => _toggleService(),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class NotificationServiceHandler extends TaskHandler {
//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
//     // Initial setup when service starts
//   }
//
//   @override
//   void onRepeatEvent(DateTime timestamp) {
//     // Just keep the service alive
//     FlutterForegroundTask.updateService(
//       notificationTitle: 'Notification Service',
//       notificationText: 'Next check in 1 hour',
//     );
//   }
//
//   @override
//   Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
//     // Cleanup when service stops
//   }
//
//   @override
//   void onReceiveData(Object data) {
//     // Handle data from main isolate if needed
//   }
//
//   @override
//   void onNotificationButtonPressed(String id) {}
//
//   @override
//   void onNotificationPressed() {}
//
//   @override
//   void onNotificationDismissed() {}
// }
