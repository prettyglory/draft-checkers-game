import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
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
          child: GameBoardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone board layout matches its visual baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844));

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_board_phone.png'),
    );
  });

  testWidgets('tablet board layout matches its visual baseline', (
    tester,
  ) async {
    await pumpGolden(tester, const Size(1180, 820));

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_board_tablet.png'),
    );
  });

  testWidgets('dark phone board layout matches its visual baseline', (
    tester,
  ) async {
    await pumpGolden(tester, const Size(390, 844), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_board_phone_dark.png'),
    );
  });

  testWidgets('dark tablet board layout matches its visual baseline', (
    tester,
  ) async {
    await pumpGolden(tester, const Size(1180, 820), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(GameBoardScreen),
      matchesGoldenFile('goldens/game_board_tablet_dark.png'),
    );
  });
}
