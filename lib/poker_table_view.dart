import 'package:flutter/material.dart';
import 'dart:math';
import 'practice_screen.dart';

class PokerTableView extends StatelessWidget {
  final String heroPosition;
  final String chartType;
  final Map<String, List<PlayingCard>> playerHands;

  const PokerTableView({
    super.key,
    required this.heroPosition,
    required this.chartType,
    required this.playerHands,
  });

  bool _hasFolded(String pos) {
    const actionOrder = ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'];
    int posIdx = actionOrder.indexOf(pos);
    int heroIdx = actionOrder.indexOf(heroPosition);

    if (chartType == 'OPR') {
      return posIdx < heroIdx;
    } else {
      return posIdx < heroIdx - 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        
        // Ellipse dimensions
        final double tableWidth = width * 0.7;
        final double tableHeight = height * 0.65;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Table
            Container(
              width: tableWidth,
              height: tableHeight,
              decoration: BoxDecoration(
                color: Colors.green.shade800,
                borderRadius: BorderRadius.circular(1000), // Stadium shape
                border: Border.all(color: Colors.brown.shade800, width: 8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
            ),
            // Players
            ..._buildPlayers(width, height),
          ],
        );
      },
    );
  }

  List<Widget> _buildPlayers(double width, double height) {
    const order = ['SB', 'BB', 'UTG', 'HJ', 'CO', 'BTN'];
    int heroIdx = order.indexOf(heroPosition);
    List<Widget> widgets = [];

    // Player position radius (slightly outside the table)
    double radiusX = width * 0.42;
    double radiusY = height * 0.38;

    for (int i = 0; i < 6; i++) {
      String pos = order[(heroIdx + i) % 6];
      // Angles: 90, 150, 210, 270, 330, 30 (in degrees)
      double angle = (90 + i * 60) * pi / 180;
      
      // Calculate position
      double x = cos(angle) * radiusX;
      double y = sin(angle) * radiusY;

      bool isHero = i == 0;
      bool folded = _hasFolded(pos);

      widgets.add(
        Align(
          alignment: Alignment(
            x / (width / 2),
            y / (height / 2),
          ),
          child: _PlayerSeat(
            position: pos,
            isHero: isHero,
            folded: folded,
            cards: playerHands[pos],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _PlayerSeat extends StatelessWidget {
  final String position;
  final bool isHero;
  final bool folded;
  final List<PlayingCard>? cards;

  const _PlayerSeat({
    required this.position,
    required this.isHero,
    required this.folded,
    this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!folded && cards != null && cards!.length == 2)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCard(cards![0], isHero),
              const SizedBox(width: 2),
              _buildCard(cards![1], isHero),
            ],
          )
        else
          SizedBox(height: isHero ? 65 : 45), // Placeholder to keep layout stable
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHero ? Colors.blue.shade700 : Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isHero ? Colors.white : Colors.grey.shade700, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                position,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (position == 'BTN') ...[
                const SizedBox(width: 4),
                Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('D', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(PlayingCard card, bool isHero) {
    double width = isHero ? 45 : 30;
    double height = isHero ? 65 : 45;
    
    return Image.asset(
      card.assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
    );
  }
}
