import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool get _supportsNotifications => Platform.isAndroid || Platform.isIOS;

  bool _initialized = false;

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
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  /// Shows an immediate test reminder.
  Future<void> showTestReminder() async {
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

  /// Schedules a daily reminder for a specific habit at [time] ("HH:mm" 24h).
  /// Uses the habit id as the notification id so it is unique per habit.
  Future<void> scheduleHabitReminder({
    required String habitId,
    required String title,
    required String time,
  }) async {
    if (!_supportsNotifications || !_initialized) return;

    final parts = time.split(':');
    if (parts.length != 2) {
      debugPrint('[NotificationService] Invalid time format: $time');
      return;
    }
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;

    final notificationId = habitId.hashCode.abs();

    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        title: title,
        body: 'Time to keep your streak alive!',
        scheduledDate: _nextInstanceOfTime(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'steady_habits',
            'Habit reminders',
            importance: Importance.defaultImportance,
            channelDescription: 'Daily reminders for individual habits',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('[NotificationService] Scheduled daily $title at $time (id=$notificationId)');
    } catch (e) {
      debugPrint('[NotificationService] Schedule error: $e');
    }
  }

  /// Cancels the reminder for a given habit.
  Future<void> cancelHabitReminder(String habitId) async {
    if (!_supportsNotifications) return;
    final notificationId = habitId.hashCode.abs();
    await _plugin.cancel(id: notificationId);
    debugPrint('[NotificationService] Cancelled reminder id=$notificationId');
  }

  /// Cancels all Steady notifications.
  Future<void> cancelAll() async {
    if (!_supportsNotifications) return;
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
