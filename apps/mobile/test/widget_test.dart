import 'package:draft_game/app/draft_game_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows an honest Phase 3 rules milestone', (tester) async {
    await tester.pumpWidget(const DraftGameApp());

    expect(find.text('Draft Game'), findsOneWidget);
    expect(
      find.text('A modern home for checkers around the world.'),
      findsOneWidget,
    );
    expect(find.text('Phase 3 · American rules ready'), findsOneWidget);
    expect(find.byType(ButtonStyleButton), findsNothing);
  });
}
