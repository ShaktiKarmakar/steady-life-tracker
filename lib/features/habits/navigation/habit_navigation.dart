import 'package:flutter/material.dart';

import '../custom_habit_screen.dart';
import '../detail/habit_detail_screen.dart';
import '../templates/new_habit_picker_screen.dart';

void openHabitDetail(BuildContext context, String habitId) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => HabitDetailScreen(habitId: habitId),
    ),
  );
}

void openNewHabitPicker(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const NewHabitPickerScreen(),
    ),
  );
}

void openCustomHabit(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => const CustomHabitScreen(),
    ),
  );
}
