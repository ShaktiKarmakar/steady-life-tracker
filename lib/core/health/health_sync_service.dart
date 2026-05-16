import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Wraps the `health` package to import workouts from Apple Health / Google Fit.
class HealthSyncService {
  final _health = Health();

  bool _authorized = false;

  /// Request Health Kit / Google Fit permissions.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      _authorized = await _health.requestAuthorization([
        HealthDataType.WORKOUT,
      ]);
      return _authorized;
    } catch (e) {
      debugPrint('[HealthSync] Permission error: $e');
      return false;
    }
  }

  /// Fetches workouts from the last [days] days and returns them as
  /// (type, durationMin, calories) tuples. Calories may be null.
  Future<List<({String type, int durationMin, int? calories})>> fetchWorkouts({
    int days = 7,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return [];

    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));

    try {
      final data = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: now,
        types: [HealthDataType.WORKOUT],
      );

      final results = <({String type, int durationMin, int? calories})>[];
      for (final point in data) {
        final value = point.value;
        if (value is! WorkoutHealthValue) continue;
        final durationMin = point.dateTo.difference(point.dateFrom).inMinutes;
        results.add((
          type: value.workoutActivityType.name,
          durationMin: durationMin > 0 ? durationMin : 30,
          calories: value.totalEnergyBurned?.toInt(),
        ));
      }
      return results;
    } catch (e) {
      debugPrint('[HealthSync] Fetch error: $e');
      return [];
    }
  }
}
