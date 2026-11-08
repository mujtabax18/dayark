// // lib/services/notification_service.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:timezone/timezone.dart' as tz;
// import 'package:timezone/data/latest.dart' as tz;
//
// class NotificationService {
//   static final NotificationService _instance = NotificationService._internal();
//   factory NotificationService() => _instance;
//   NotificationService._internal();
//
//   final FlutterLocalNotificationsPlugin notificationsPlugin =
//       FlutterLocalNotificationsPlugin();
//
//   Future<void> initialize() async {
//     tz.initializeTimeZones();
//
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings initializationSettings =
//         InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: DarwinInitializationSettings(),
//     );
//
//     await notificationsPlugin.initialize(initializationSettings);
//   }
//
//   Future<void> showNotification({
//     required int id,
//     required String title,
//     required String body,
//   }) async {
//     const AndroidNotificationDetails androidNotificationDetails =
//         AndroidNotificationDetails(
//       'habit_quotes_channel',
//       'Motivational Quotes',
//       importance: Importance.high,
//       priority: Priority.high,
//       showWhen: false,
//     );
//
//     const NotificationDetails notificationDetails =
//         NotificationDetails(android: androidNotificationDetails);
//
//     await notificationsPlugin.show(
//       id,
//       title,
//       body,
//       notificationDetails,
//     );
//   }
//
//   Future<void> scheduleDailyNotification({
//     required int id,
//     required TimeOfDay time,
//     required String title,
//     required String body,
//   }) async {
//     final now = tz.TZDateTime.now(tz.local);
//     var scheduledTime = tz.TZDateTime(
//       tz.local,
//       now.year,
//       now.month,
//       now.day,
//       time.hour,
//       time.minute,
//     );
//
//     if (scheduledTime.isBefore(now)) {
//       scheduledTime = scheduledTime.add(const Duration(days: 1));
//     }
//
//     const AndroidNotificationDetails androidNotificationDetails =
//         AndroidNotificationDetails(
//       'daily_quotes_channel',
//       'Daily Motivational Quotes',
//       importance: Importance.high,
//       priority: Priority.high,
//     );
//
//     await notificationsPlugin.zonedSchedule(
//       id,
//       title,
//       body,
//       scheduledTime,
//       const NotificationDetails(android: androidNotificationDetails),
//       // androidAllowWhileIdle: true,
//       // uiLocalNotificationDateInterpretation:
//       //     UILocalNotificationDateInterpretation.absoluteTime,
//       matchDateTimeComponents: DateTimeComponents.time,
//       androidScheduleMode: AndroidScheduleMode.alarmClock,
//     );
//   }
//
//   Future<void> cancelAllNotifications() async {
//     await notificationsPlugin.cancelAll();
//   }
// }
