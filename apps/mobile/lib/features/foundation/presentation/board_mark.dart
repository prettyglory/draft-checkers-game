import 'package:flutter/material.dart';

class BoardMark extends StatelessWidget {
  const BoardMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      image: true,
      label: 'Draft Game checkerboard logo',
      child: ExcludeSemantics(
        child: Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 16,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                  ),
                  itemBuilder: (context, index) {
                    final row = index ~/ 4;
                    final column = index % 4;
                    final darkSquare = (row + column).isOdd;
                    return ColoredBox(
                      color: darkSquare
                          ? scheme.primary
                          : scheme.primaryContainer,
                    );
                  },
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tertiary,
                    border: Border.all(
                      color: scheme.onTertiary.withValues(alpha: 0.75),
                      width: 4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.32),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(Icons.star_rounded, color: scheme.onTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
