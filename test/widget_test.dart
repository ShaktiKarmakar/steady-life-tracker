import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:steady_life_tracker/core/db/database.dart';
import 'package:steady_life_tracker/core/router/app_router.dart';
import 'package:steady_life_tracker/main.dart';

void main() {
  testWidgets('Steady app renders onboarding', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final db = LocalDatabase();
    await db.initialize();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          initialLocationProvider.overrideWithValue('/onboarding'),
        ],
        child: const SteadyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Steady'), findsOneWidget);
  });
}
