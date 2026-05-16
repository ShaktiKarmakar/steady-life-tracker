import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  late LocalDatabase _db;

  @override
  ThemeMode build() {
    _db = ref.read(databaseProvider);
    return _db.themeMode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _db.setThemeMode(mode);
  }

  Future<void> toggle() async {
    final next = switch (state) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    await setMode(next);
  }
}
