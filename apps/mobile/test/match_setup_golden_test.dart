import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/match_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpGolden(
    WidgetTester tester,
    Size size, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MatchSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone setup matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844));

    await expectLater(
      find.byType(MatchSetupScreen),
      matchesGoldenFile('goldens/match_setup_phone.png'),
    );
  });

  testWidgets('phone setup matches its dark baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(MatchSetupScreen),
      matchesGoldenFile('goldens/match_setup_phone_dark.png'),
    );
  });

  testWidgets('tablet setup matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820));

    await expectLater(
      find.byType(MatchSetupScreen),
      matchesGoldenFile('goldens/match_setup_tablet.png'),
    );
  });

  testWidgets('tablet setup matches its dark baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(MatchSetupScreen),
      matchesGoldenFile('goldens/match_setup_tablet_dark.png'),
    );
  });
}
