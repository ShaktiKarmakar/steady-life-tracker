import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool get _supportsNotifications => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!_supportsNotifications) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> scheduleHabitReminder() async {
    if (!_supportsNotifications) return;
    await _plugin.show(
      id: 1001,
      title: 'Steady reminder',
      body: 'Take 30 seconds to complete your key habit.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'steady_habits',
          'Habit reminders',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
