import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/settings/application/settings_controller.dart';
import 'package:draft_game/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_settings_repository.dart';

void main() {
  Future<void> pumpGolden(
    WidgetTester tester,
    Size size, {
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final controller = SettingsController(
      settingsRepository: MemorySettingsRepository(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SettingsScreen(controller: controller),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone settings matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844));

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_phone.png'),
    );
  });

  testWidgets('phone settings matches its dark baseline', (tester) async {
    await pumpGolden(tester, const Size(390, 844), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_phone_dark.png'),
    );
  });

  testWidgets('tablet settings matches its light baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820));

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_tablet.png'),
    );
  });

  testWidgets('tablet settings matches its dark baseline', (tester) async {
    await pumpGolden(tester, const Size(1180, 820), themeMode: ThemeMode.dark);

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_tablet_dark.png'),
    );
  });
}
