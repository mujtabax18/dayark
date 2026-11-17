import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Best-effort, local-only notification used when a reply finishes while the
/// app is not visible. Provider content is deliberately excluded from it.
class AiChatNotifications {
  AiChatNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> showReplyReady({required bool failed}) async {
    try {
      if (!_initialized) {
        const initialization = InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Open AI Chat'),
        );
        await _plugin.initialize(settings: initialization);
        _initialized = true;
      }
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'ai_chat_replies',
          'AI chat replies',
          channelDescription: 'Notifies when a DayArk AI reply is ready.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
      );
      await _plugin.show(
        id: 820001,
        title: failed ? 'AI reply needs attention' : 'AI reply is ready',
        body: failed
            ? 'Open AI Chat to review the provider details and retry.'
            : 'Open DayArk to read the completed response.',
        notificationDetails: details,
        payload: 'ai_chat',
      );
    } catch (error) {
      debugPrint('AI reply notification unavailable: $error');
    }
  }
}
