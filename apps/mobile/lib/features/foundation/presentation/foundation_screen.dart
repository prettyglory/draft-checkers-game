import 'package:draft_game/features/foundation/presentation/board_mark.dart';
import 'package:flutter/material.dart';

class FoundationScreen extends StatelessWidget {
  const FoundationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const BoardMark(),
                  const SizedBox(height: 36),
                  Semantics(
                    header: true,
                    child: Text(
                      'Draft Game',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A modern home for checkers around the world.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.architecture_rounded,
                            size: 20,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Phase 1 · Foundation ready',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
