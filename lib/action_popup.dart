import 'package:flutter/material.dart';
import 'theme.dart';

class ActionPopup extends StatelessWidget {
  final Rect cellRect;
  final String hand;
  final Map<String, int> actionWeights;
  final Set<String> uniqueActions;

  const ActionPopup({
    super.key,
    required this.cellRect,
    required this.hand,
    required this.actionWeights,
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

  @override
  Widget build(BuildContext context) {
    final chartColors = Theme.of(context).extension<ChartColors>()!;
    
    int foldWeight = actionWeights.entries
        .where((e) => e.key.toLowerCase().contains('fold'))
        .fold(0, (sum, e) => sum + e.value);
    int nonFoldTotal = 0;
    actionWeights.forEach((k, v) {
      if (!k.toLowerCase().contains('fold')) {
        nonFoldTotal += v;
      }
    });
    if (foldWeight == 0 && nonFoldTotal < 100) {
      foldWeight = 100 - nonFoldTotal;
    }

    final List<Widget> actionRows = [];

    void addActionRow(String action, int weight) {
      if (weight <= 0) return;
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

    actionWeights.forEach((action, weight) {
      if (!action.toLowerCase().contains('fold')) {
        addActionRow(action, weight);
      }
    });

    if (foldWeight > 0) {
      String foldLabel = uniqueActions.firstWhere(
        (a) => a.toLowerCase().contains('fold'),
        orElse: () => 'Fold',
      );
      addActionRow(foldLabel, foldWeight);
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