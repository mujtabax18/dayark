import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:metersystem/models/moodTrackerModel.dart';

class DiaryReminderService {
  DiaryReminderService._();

  static const _channelId = 'diary_reminders';
  static const _channelName = 'Diary reminders';
  static const _channelDescription =
      'Private reminders to write or revisit diary entries.';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (error) {
      debugPrint('Diary timezone initialization failed: $error');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<void> scheduleFor(MoodEntry entry) async {
    await initialize();
    await _ensurePermission();
    final id = entry.id;
    final reminder = entry.reminderDateTime;
    if (id == null ||
        !entry.reminderEnabled ||
        reminder == null ||
        !reminder.isAfter(DateTime.now())) {
      if (id != null) await cancel(id);
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      id: _notificationId(id),
      title: 'Diary reminder',
      body: entry.title.trim().isEmpty
          ? 'Take a quiet moment to write in your diary.'
          : entry.title.trim(),
      scheduledDate: tz.TZDateTime.from(reminder, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'diary_entry:$id',
    );
  }

  static Future<void> _ensurePermission() async {
    final androidGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final iosGranted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (androidGranted == false || iosGranted == false) {
      throw StateError(
        'Notification permission is disabled. Enable it in device settings.',
      );
    }
  }

  static Future<void> cancel(int entryId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(entryId));
  }

  /// Removes native notifications that would otherwise outlive diary rows
  /// after a destructive database reset.
  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static int _notificationId(int entryId) => 700000 + (entryId % 2000000000);
}
