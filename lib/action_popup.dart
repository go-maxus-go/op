import 'package:flutter/material.dart' hide Card;
import 'theme.dart';
import 'card.dart';
import 'utils/chart_parser.dart';
import 'utils/range_parser.dart';

class ActionPopup extends StatelessWidget {
  final Rect cellRect;
  final String hand;
  final Map<String, String> comboActions;
  final Set<String> uniqueActions;

  const ActionPopup({
    super.key,
    required this.cellRect,
    required this.hand,
    required this.comboActions,
    required this.uniqueActions,
  });

  Color _getColorForAction(String actionName, ChartColors colors) {
    final lowerAction = actionName.toLowerCase();
    if (lowerAction.contains('fold')) return colors.foldColor;
    if (lowerAction.contains('call')) return colors.callColor;
    if (lowerAction.contains('raise')) return colors.raiseColor;
    if (lowerAction.contains('all-in') || lowerAction.contains('shove')) {
      return colors.allInColor;
    }
    return colors.defaultColor;
  }

  String _actionForCombo(String combo) {
    try {
      return comboActions[RangeParser.normalizeCombo(combo)] ??
          PositionChart.foldLabel;
    } catch (_) {
      return PositionChart.foldLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chartColors = Theme.of(context).extension<ChartColors>()!;
    final comboRows = RangeParser.comboLayoutForHand(hand);
    final actionCounts = <String, int>{};
    for (final row in comboRows) {
      for (final combo in row) {
        final action = _actionForCombo(combo);
        actionCounts[action] = (actionCounts[action] ?? 0) + 1;
      }
    }
    final totalCombos = actionCounts.values.fold<int>(
      0,
      (sum, count) => sum + count,
    );

    final actionNames = uniqueActions.toSet();
    for (final action in actionCounts.keys) {
      actionNames.add(action);
    }
    final sortedActions = actionNames.toList()
      ..sort((a, b) {
        int getPriority(String action) {
          final lower = action.toLowerCase();
          if (lower.contains('all-in') || lower.contains('shove')) return 0;
          if (lower.contains('raise')) return 1;
          if (lower.contains('call')) return 2;
          if (lower.contains('fold')) return 3;
          return 4;
        }

        return getPriority(a).compareTo(getPriority(b));
      });

    final List<Widget> actionRows = [];
    for (final action in sortedActions) {
      final count = actionCounts[action] ?? 0;
      if (count <= 0 || totalCombos == 0) {
        continue;
      }
      final weight = ((count / totalCombos) * 100).round();
      actionRows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getColorForAction(action, chartColors),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$action: ',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '$weight%',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return CustomSingleChildLayout(
      delegate: PopupLayoutDelegate(cellRect, MediaQuery.of(context).size),
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color:
            Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hand: $hand',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              ...actionRows,
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: comboRows.map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: row.map((combo) {
                          final action = _actionForCombo(combo);
                          final isFold = action.toLowerCase().contains('fold');
                          final c1 = Card(combo[0], combo[1]);
                          final c2 = Card(combo[2], combo[3]);
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3.0),
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: _getColorForAction(
                                action,
                                chartColors,
                              ).withValues(alpha: isFold ? 0.15 : 0.35),
                              border: Border.all(
                                color: _getColorForAction(action, chartColors),
                                width: isFold ? 1 : 2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(c1.assetPath, width: 28, height: 39),
                                const SizedBox(width: 2),
                                Image.asset(c2.assetPath, width: 28, height: 39),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PopupLayoutDelegate extends SingleChildLayoutDelegate {
  final Rect cellRect;
  final Size screenSize;

  PopupLayoutDelegate(this.cellRect, this.screenSize);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: screenSize.width,
      maxHeight: screenSize.height,
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    double dx = cellRect.right;
    double dy = cellRect.bottom - childSize.height;

    // If too high (dy < 0), display bottom right (top of popup aligned with top of cell)
    if (dy < 0) {
      dy = cellRect.top;
    }

    // If too right, display on the left side
    if (dx + childSize.width > screenSize.width) {
      dx = cellRect.left - childSize.width;
    }

    // Safety checks to prevent clipping
    if (dx < 0) dx = 0;
    if (dy < 0) dy = 0;
    if (dy + childSize.height > screenSize.height) {
      dy = screenSize.height - childSize.height;
    }

    return Offset(dx, dy);
  }

  @override
  bool shouldRelayout(PopupLayoutDelegate oldDelegate) {
    return cellRect != oldDelegate.cellRect ||
        screenSize != oldDelegate.screenSize;
  }
}
