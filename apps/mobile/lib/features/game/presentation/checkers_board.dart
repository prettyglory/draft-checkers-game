import 'package:checkers_engine/checkers_engine.dart';
import 'package:draft_game/features/game/presentation/game_board_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class CheckersBoard extends StatelessWidget {
  const CheckersBoard({
    required this.viewModel,
    this.rotateBoard = false,
    this.largerLabels = false,
    super.key,
  });

  final GameBoardViewModel viewModel;
  final bool rotateBoard;
  final bool largerLabels;

  @override
  Widget build(BuildContext context) {
    final state = viewModel.state;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Semantics(
      container: true,
      label:
          'American checkers board. ${viewModel.statusTitle}. '
          '${viewModel.statusDetail}. '
          '${rotateBoard ? 'Dark' : 'Light'} side at bottom.',
      child: RepaintBoundary(
        key: const Key('game-board'),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.shadow,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow
                    .withValues(alpha: 0.22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: GridView.builder(
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.boardSize * state.boardSize,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: state.boardSize,
            ),
            itemBuilder: (context, index) {
              final logicalIndex = rotateBoard
                  ? state.boardSize * state.boardSize - 1 - index
                  : index;
              final row = logicalIndex ~/ state.boardSize;
              final column = logicalIndex % state.boardSize;
              final position = BoardPosition(row: row, column: column);
              return _BoardSquare(
                position: position,
                visualIndex: index,
                viewModel: viewModel,
                duration: duration,
                largerLabels: largerLabels,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BoardSquare extends StatelessWidget {
  const _BoardSquare({
    required this.position,
    required this.visualIndex,
    required this.viewModel,
    required this.duration,
    required this.largerLabels,
  });

  final BoardPosition position;
  final int visualIndex;
  final GameBoardViewModel viewModel;
  final Duration duration;
  final bool largerLabels;

  @override
  Widget build(BuildContext context) {
    final playable = (position.row + position.column).isOdd;
    final piece = viewModel.displayPieceAt(position);
    final selectable =
        piece != null &&
        !viewModel.isPathInProgress &&
        viewModel.selectablePieceIds.contains(piece.id);
    final selected = piece?.id == viewModel.selectedPieceId;
    final target = viewModel.targetPositions.contains(position);
    final pathStep = viewModel.pathStepAt(position);
    final interactive = playable && (selectable || target);
    final finalTarget = target && viewModel.isFinalTarget(position);
    final scheme = Theme.of(context).colorScheme;
    final squareColor = playable
        ? (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF31584C)
              : const Color(0xFF547C6D))
        : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFFB8AA8E)
              : const Color(0xFFE7D8BA));
    final highlighted = selected || target || pathStep != null;

    final visual = AnimatedContainer(
      key: Key('board-cell-${position.row}-${position.column}'),
      duration: duration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: squareColor,
        border: Border.all(
          color: highlighted ? scheme.tertiary : Colors.transparent,
          width: highlighted ? 3 : 0,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: <Widget>[
          if (target)
            Center(
              child: _TargetMarker(
                key: Key('target-${position.row}-${position.column}'),
                isFinal: finalTarget,
                color: scheme.onPrimary,
              ),
            ),
          if (piece != null)
            Center(
              child: _CheckerPiece(
                key: Key('piece-${piece.id}'),
                piece: piece,
                selected: selected,
                selectable: selectable,
                duration: duration,
              ),
            ),
          if (pathStep != null && pathStep > 0)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                key: Key('path-${position.row}-${position.column}-$pathStep'),
                width: largerLabels ? 23 : 19,
                height: largerLabels ? 23 : 19,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.onTertiaryContainer),
                ),
                child: Text(
                  '$pathStep',
                  style: TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontSize: largerLabels ? 14 : 11,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (!playable) {
      return ExcludeSemantics(child: visual);
    }

    return Semantics(
      key: Key('square-${position.row}-${position.column}'),
      container: true,
      excludeSemantics: true,
      sortKey: OrdinalSortKey(visualIndex.toDouble()),
      label: _semanticLabel(
        piece: piece,
        selectable: selectable,
        selected: selected,
        target: target,
        finalTarget: finalTarget,
        pathStep: pathStep,
      ),
      button: interactive,
      enabled: interactive,
      selected: selected,
      onTap: interactive ? () => viewModel.tapSquare(position) : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          excludeFromSemantics: true,
          canRequestFocus: interactive,
          onTap: interactive ? () => viewModel.tapSquare(position) : null,
          child: visual,
        ),
      ),
    );
  }

  String _semanticLabel({
    required Piece? piece,
    required bool selectable,
    required bool selected,
    required bool target,
    required bool finalTarget,
    required int? pathStep,
  }) {
    final squareNumber = position.row * 4 + position.column ~/ 2 + 1;
    final parts = <String>['Square $squareNumber'];
    if (piece == null) {
      parts.add('empty');
    } else {
      final side = piece.side == PlayerSide.dark ? 'dark' : 'light';
      final rank = piece.rank == PieceRank.king ? 'king' : 'man';
      parts.add('$side $rank');
    }
    if (selected) {
      parts.add('selected');
    } else if (selectable) {
      parts.add('selectable');
    }
    if (target) {
      parts.add(finalTarget ? 'legal destination' : 'next capture landing');
    }
    if (pathStep != null && pathStep > 0) {
      parts.add('capture path step $pathStep');
    }
    return '${parts.join(', ')}.';
  }
}

class _TargetMarker extends StatelessWidget {
  const _TargetMarker({required this.isFinal, required this.color, super.key});

  final bool isFinal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: 0.44,
      heightFactor: 0.44,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color, width: isFinal ? 4 : 3),
        ),
        child: isFinal
            ? Center(
                child: FractionallySizedBox(
                  widthFactor: 0.3,
                  heightFactor: 0.3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              )
            : Icon(Icons.add_rounded, color: color, size: 18),
      ),
    );
  }
}

class _CheckerPiece extends StatelessWidget {
  const _CheckerPiece({
    required this.piece,
    required this.selected,
    required this.selectable,
    required this.duration,
    super.key,
  });

  final Piece piece;
  final bool selected;
  final bool selectable;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final dark = piece.side == PlayerSide.dark;
    final fill = dark ? const Color(0xFF17221F) : const Color(0xFFF9F2E6);
    final edge = dark ? const Color(0xFFEBCB77) : const Color(0xFF284E43);

    return AnimatedScale(
      duration: duration,
      curve: Curves.easeOutBack,
      scale: selected ? 1.08 : 1,
      child: FractionallySizedBox(
        widthFactor: 0.74,
        heightFactor: 0.74,
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: const Alignment(-0.25, -0.3),
              colors: <Color>[
                Color.lerp(fill, Colors.white, dark ? 0.18 : 0.5)!,
                fill,
              ],
            ),
            border: Border.all(
              color: edge,
              width: selected || selectable ? 4 : 2.5,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: selected ? 9 : 5,
                offset: Offset(0, selected ? 4 : 3),
              ),
            ],
          ),
          child: Center(
            child: piece.rank == PieceRank.king
                ? Icon(Icons.star_rounded, color: edge, size: 27)
                : Icon(
                    dark ? Icons.circle : Icons.circle_outlined,
                    color: edge,
                    size: dark ? 11 : 19,
                  ),
          ),
        ),
      ),
    );
  }
}
