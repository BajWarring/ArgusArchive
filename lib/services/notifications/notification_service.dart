import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final StreamController<String> actionStream = StreamController<String>.broadcast();

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == 'cancel_op') {
          actionStream.add(response.payload ?? '');
        }
      },
    );

    // Request permissions for Android 13+
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
  }

  static Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required String payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'op_progress_channel',
      'File Operations',
      channelDescription: 'Shows progress for file operations like copy, move, and compress.',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction('open_op', 'Open', showsUserInterface: true),
        const AndroidNotificationAction('cancel_op', 'Cancel', showsUserInterface: false),
      ],
    );

    await _plugin.show(id, title, body, NotificationDetails(android: androidDetails), payload: payload);
  }

  static Future<void> showCompletionNotification({required int id, required String title, required String body}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'op_complete_channel', 'Operation Alerts',
      importance: Importance.high, priority: Priority.high,
      ongoing: false, autoCancel: true,
    );
    await _plugin.show(id, title, body, const NotificationDetails(android: androidDetails));
  }

  static Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
