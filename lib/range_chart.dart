import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Card;

import 'card.dart';
import 'theme.dart';

class RangeChart {
  static const int size = 13;

  static String handAt(int row, int col) {
    final r1 = Card.ranks[12 - row];
    final r2 = Card.ranks[12 - col];

    if (row == col) {
      return '$r1$r2';
    } else if (col > row) {
      return '$r1${r2}s';
    } else {
      return '$r2${r1}o';
    }
  }

  static List<String> combosForHand(String hand) {
    if (hand.length == 2) {
      final r = hand[0];
      return [
        '${r}s${r}h',
        '${r}s${r}c',
        '${r}s${r}d',
        '${r}h${r}c',
        '${r}h${r}d',
        '${r}c${r}d',
      ];
    } else if (hand.endsWith('s')) {
      final r1 = hand[0];
      final r2 = hand[1];
      return ['${r1}s${r2}s', '${r1}h${r2}h', '${r1}c${r2}c', '${r1}d${r2}d'];
    } else {
      final r1 = hand[0];
      final r2 = hand[1];
      final suits = ['s', 'h', 'c', 'd'];
      final combos = <String>[];
      for (var s1 in suits) {
        for (var s2 in suits) {
          if (s1 != s2) {
            combos.add('$r1$s1$r2$s2');
          }
        }
      }
      return combos;
    }
  }

  static int selectedCount(String hand, Set<String> selectedCombos) {
    return combosForHand(hand).where(selectedCombos.contains).length;
  }

  static Color cellColor({
    required BuildContext context,
    required int row,
    required int col,
    required Set<String> selectedCombos,
  }) {
    final chartColors = Theme.of(context).extension<ChartColors>()!;
    final hand = handAt(row, col);
    final total = combosForHand(hand).length;
    final selected = selectedCount(hand, selectedCombos);

    if (selected == 0) {
      return Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    final Color handColor;
    if (row == col) {
      handColor = chartColors.pairColor;
    } else if (col > row) {
      handColor = chartColors.suitedColor;
    } else {
      handColor = chartColors.offsuitColor;
    }
    return selected == total ? handColor : handColor.withValues(alpha: 0.5);
  }
}

class RangeChartImage extends StatelessWidget {
  final Set<String> range;
  final double size;

  const RangeChartImage({super.key, required this.range, this.size = 70});

  @override
  Widget build(BuildContext context) {
    final colors = [
      for (var row = 0; row < RangeChart.size; row++)
        for (var col = 0; col < RangeChart.size; col++)
          RangeChart.cellColor(
            context: context,
            row: row,
            col: col,
            selectedCombos: range,
          ),
    ];
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RangeChartPainter(colors)),
    );
  }
}

class _RangeChartPainter extends CustomPainter {
  final List<Color> colors;

  _RangeChartPainter(this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 0.5;
    final cell = (size.width - gap * (RangeChart.size - 1)) / RangeChart.size;
    final paint = Paint();
    for (var row = 0; row < RangeChart.size; row++) {
      for (var col = 0; col < RangeChart.size; col++) {
        paint.color = colors[row * RangeChart.size + col];
        canvas.drawRect(
          Rect.fromLTWH(col * (cell + gap), row * (cell + gap), cell, cell),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RangeChartPainter oldDelegate) {
    return !listEquals(oldDelegate.colors, colors);
  }
}
