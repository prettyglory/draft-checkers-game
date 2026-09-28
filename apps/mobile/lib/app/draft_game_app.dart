import 'package:draft_game/app/theme/app_theme.dart';
import 'package:draft_game/features/game/presentation/game_board_screen.dart';
import 'package:flutter/material.dart';

class DraftGameApp extends StatelessWidget {
  const DraftGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Draft Game',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const GameBoardScreen(),
    );
  }
}
