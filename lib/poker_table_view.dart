import 'package:flutter/material.dart' hide Card;
import 'dart:math';
import 'card.dart';

class PokerTableView extends StatelessWidget {
  final String heroPosition;
  final String chartType;
  final String raise;
  final String limit;
  final bool displayInDollars;
  final bool showOpponentCards;
  final Map<String, List<Card>> playerHands;
  final Widget? heroTrailing;

  /// Space below the table taken by the hero's label, which sits under the
  /// hand. Parents should add it to the height they give this view.
  static const double heroExtraHeight =
      _SeatCards.heroCardHeight / 2 + _TableLayoutDelegate.cardGap + 18;

  const PokerTableView({
    super.key,
    required this.heroPosition,
    required this.chartType,
    required this.raise,
    required this.limit,
    required this.displayInDollars,
    this.showOpponentCards = true,
    required this.playerHands,
    this.heroTrailing,
  });

  bool _hasFolded(String pos) {
    const actionOrder = ['UTG', 'HJ', 'CO', 'BTN', 'SB', 'BB'];
    int posIdx = actionOrder.indexOf(pos);
    int heroIdx = actionOrder.indexOf(heroPosition);

    if (chartType == 'OPR') {
      return posIdx < heroIdx;
    } else if (chartType.startsWith('vs_') && chartType.endsWith('_opr')) {
      String raiserPos = chartType.split('_')[1].toUpperCase();
      if (pos == raiserPos) return false;
      return posIdx < heroIdx;
    } else {
      return posIdx < heroIdx - 1;
    }
  }

  String? _getBetAmount(String pos) {
    if (chartType.startsWith('vs_') && chartType.endsWith('_opr')) {
      String raiserPos = chartType.split('_')[1].toUpperCase();
      if (pos == raiserPos) {
        return raise.replaceAll('bb', '');
      }
    }

    if (pos == 'SB') return '0.5';
    if (pos == 'BB') return '1.0';

    return null;
  }

  double _bbFactor() {
    if (limit.toUpperCase() == 'NL50') return 0.5;
    if (limit.toUpperCase() == 'NL200') return 2.0;
    return 1.0;
  }

  String _formatBet(String amountStr) {
    double amountBb = double.tryParse(amountStr) ?? 0.0;
    if (displayInDollars) {
      double amountDollars = amountBb * _bbFactor();
      return '${amountDollars.toStringAsFixed(amountDollars.truncateToDouble() == amountDollars ? 0 : 2)}\$';
    }
    return amountBb.toStringAsFixed(amountBb.truncateToDouble() == amountBb ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    const order = ['SB', 'BB', 'UTG', 'HJ', 'CO', 'BTN'];
    int heroIdx = order.indexOf(heroPosition);

    final tableLayer = <Widget>[
      LayoutId(
        id: _TableLayoutDelegate.tableId,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.green.shade800,
            borderRadius: BorderRadius.circular(1000), // Stadium shape
            border: Border.all(
              color: Colors.brown.shade800,
              width: _TableLayoutDelegate.borderWidth,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
        ),
      ),
    ];
    final betLayer = <Widget>[];
    final cardLayer = <Widget>[];
    final labelLayer = <Widget>[];

    for (int i = 0; i < order.length; i++) {
      String pos = order[(heroIdx + i) % order.length];
      bool isHero = i == 0;
      bool folded = _hasFolded(pos);
      final cards = playerHands[pos];

      labelLayer.add(LayoutId(
        id: _TableLayoutDelegate.labelId(i),
        child: _SeatLabel(position: pos, isHero: isHero),
      ));

      if (!folded && cards != null && cards.length == 2) {
        cardLayer.add(LayoutId(
          id: _TableLayoutDelegate.cardsId(i),
          child: _SeatCards(
            cards: cards,
            isHero: isHero,
            faceDown: !isHero && !showOpponentCards,
          ),
        ));

        if (isHero && heroTrailing != null) {
          labelLayer.add(LayoutId(
            id: _TableLayoutDelegate.heroTrailingId,
            child: SizedBox(
              width: _TableLayoutDelegate.heroTrailingSize,
              height: _TableLayoutDelegate.heroTrailingSize,
              child: heroTrailing,
            ),
          ));
        }
      }

      String? amountStr = _getBetAmount(pos);
      if (amountStr != null) {
        betLayer.add(LayoutId(
          id: _TableLayoutDelegate.betId(i),
          child: _BetChip(text: _formatBet(amountStr)),
        ));
      }
    }

    return CustomMultiChildLayout(
      delegate: _TableLayoutDelegate(seatCount: order.length),
      children: [...tableLayer, ...betLayer, ...cardLayer, ...labelLayer],
    );
  }
}

/// Sizes the table to the available space and anchors each seat label's
/// center on the table border, with cards and bets placed towards the felt.
class _TableLayoutDelegate extends MultiChildLayoutDelegate {
  final int seatCount;

  _TableLayoutDelegate({required this.seatCount});

  static const String tableId = 'table';
  static String labelId(int i) => 'label$i';
  static String cardsId(int i) => 'cards$i';
  static String betId(int i) => 'bet$i';
  static const String heroTrailingId = 'heroTrailing';

  static const double heroTrailingSize = 40;
  static const double _heroTrailingGap = 4;
  static const double borderWidth = 8;
  static const double _outerMargin = 4;
  static const double cardGap = 2;
  static const double _betGap = 6;

  @override
  void performLayout(Size size) {
    final loose = BoxConstraints.loose(size);

    final labelSizes = <Size>[];
    double maxHalfH = 0;
    for (int i = 0; i < seatCount; i++) {
      final s = layoutChild(labelId(i), loose);
      labelSizes.add(s);
      maxHalfH = max(maxHalfH, s.height / 2);
    }

    // Seats at the top of the table hold their cards above the label.
    final topMargin = maxHalfH -
        borderWidth / 2 +
        cardGap +
        _SeatCards.villainCardHeight;
    final bottomMargin =
        maxHalfH + _outerMargin + PokerTableView.heroExtraHeight;
    final tableHeight = max(0.0, size.height - topMargin - bottomMargin);
    final halfH = max(0.0, tableHeight / 2 - borderWidth / 2);

    // Size for the widest seat everywhere so the table doesn't change as
    // positions rotate.
    final seatHalfWidth = max(
          labelSizes.map((s) => s.width).reduce(max),
          2 * _SeatCards.villainCardWidth + 2,
        ) /
        2;

    // Widest table whose seats still fit horizontally.
    double lo = 0;
    double hi = max(0.0, size.width / 2 - borderWidth / 2);
    for (int iter = 0; iter < 24; iter++) {
      final mid = (lo + hi) / 2;
      double extent = 0;
      for (int i = 0; i < seatCount; i++) {
        final seat = _seatOffset(i, mid, halfH);
        extent = max(extent, seat.dx.abs() + seatHalfWidth);
      }
      if (extent <= size.width / 2 - _outerMargin) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final halfW = lo;

    final tableSize = Size(2 * halfW + borderWidth, tableHeight);
    final center = Offset(size.width / 2, topMargin + tableSize.height / 2);
    layoutChild(tableId, BoxConstraints.tight(tableSize));
    positionChild(tableId, center - tableSize.center(Offset.zero));

    for (int i = 0; i < seatCount; i++) {
      final dir = _seatDirection(i, halfW, halfH);
      final anchor = center + _stadiumEdge(dir, halfW, halfH);

      final isHero = i == 0;
      final labelSize = labelSizes[i];
      // The hero's hand is centered on the edge, with the label below it.
      final labelCenter = isHero
          ? anchor.translate(
              0,
              _SeatCards.heroCardHeight / 2 + cardGap + labelSize.height / 2,
            )
          : anchor;
      final labelRect = Rect.fromCenter(
        center: labelCenter,
        width: labelSize.width,
        height: labelSize.height,
      );
      positionChild(labelId(i), labelRect.topLeft);

      Rect seatRect = labelRect;
      if (hasChild(cardsId(i))) {
        final cardsSize = layoutChild(cardsId(i), loose);
        final cardsOffset = Offset(
          anchor.dx - cardsSize.width / 2,
          isHero
              ? anchor.dy - cardsSize.height / 2
              : labelRect.top - cardGap - cardsSize.height,
        );
        positionChild(cardsId(i), cardsOffset);
        seatRect = seatRect.expandToInclude(cardsOffset & cardsSize);
      }

      if (i == 0 && hasChild(heroTrailingId)) {
        final trailingSize = layoutChild(heroTrailingId, loose);
        final trailingOffset = Offset(
          labelRect.right + _heroTrailingGap,
          labelRect.center.dy - trailingSize.height / 2,
        );
        positionChild(heroTrailingId, trailingOffset);
        seatRect = seatRect.expandToInclude(trailingOffset & trailingSize);
      }

      if (hasChild(betId(i))) {
        final betSize = layoutChild(betId(i), loose);
        final towardCenter = -dir;
        final clearRect = Rect.fromLTRB(
          seatRect.left - _betGap - betSize.width / 2,
          seatRect.top - _betGap - betSize.height / 2,
          seatRect.right + _betGap + betSize.width / 2,
          seatRect.bottom + _betGap + betSize.height / 2,
        );
        double s = (anchor - center).distance;
        if (towardCenter.dx.abs() > 1e-6) {
          final edgeX =
              towardCenter.dx > 0 ? clearRect.right : clearRect.left;
          s = min(s, (edgeX - anchor.dx) / towardCenter.dx);
        }
        if (towardCenter.dy.abs() > 1e-6) {
          final edgeY =
              towardCenter.dy > 0 ? clearRect.bottom : clearRect.top;
          s = min(s, (edgeY - anchor.dy) / towardCenter.dy);
        }
        final betCenter = anchor + towardCenter * max(0.0, s);
        positionChild(
          betId(i),
          betCenter - Offset(betSize.width / 2, betSize.height / 2),
        );
      }
    }
  }

  /// Direction from the table center to seat [i], spread like on an ellipse
  /// matching the table's proportions.
  Offset _seatDirection(int i, double halfW, double halfH) {
    final angle = (90 + i * 360 / seatCount) * pi / 180;
    return _normalize(Offset(cos(angle) * halfW, sin(angle) * halfH));
  }

  /// Seat [i]'s position on the border center line, relative to the center.
  Offset _seatOffset(int i, double halfW, double halfH) =>
      _stadiumEdge(_seatDirection(i, halfW, halfH), halfW, halfH);

  static Offset _normalize(Offset o) {
    final d = o.distance;
    return d == 0 ? const Offset(0, 1) : o / d;
  }

  /// Point where a ray from the center in direction [dir] (unit vector)
  /// crosses a stadium with half extents [halfW] x [halfH].
  static Offset _stadiumEdge(Offset dir, double halfW, double halfH) {
    final dx = dir.dx.abs();
    final dy = dir.dy.abs();
    final r = min(halfW, halfH);

    double t = min(
      dx > 1e-9 ? halfW / dx : double.infinity,
      dy > 1e-9 ? halfH / dy : double.infinity,
    );

    final cx = halfW - r;
    final cy = halfH - r;
    if (t * dx > cx && t * dy > cy) {
      final dot = dx * cx + dy * cy;
      t = dot + sqrt(max(0.0, dot * dot - (cx * cx + cy * cy) + r * r));
    }
    return dir * t;
  }

  @override
  bool shouldRelayout(_TableLayoutDelegate oldDelegate) =>
      oldDelegate.seatCount != seatCount;
}

class _BetChip extends StatelessWidget {
  final String text;

  const _BetChip({required this.text});

  @override
  Widget build(BuildContext context) {
    const shadows = [
      Shadow(color: Colors.black87, offset: Offset(0, 1.5), blurRadius: 3),
    ];
    const baseStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w900,
      height: 1.1,
      letterSpacing: 0.3,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🪙', style: TextStyle(fontSize: 15, shadows: shadows)),
        const SizedBox(width: 3),
        Stack(
          children: [
            Text(
              text,
              style: baseStyle.copyWith(
                shadows: shadows,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..strokeJoin = StrokeJoin.round
                  ..color = Colors.black,
              ),
            ),
            Text(
              text,
              style: baseStyle.copyWith(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }
}

class _SeatCards extends StatelessWidget {
  final List<Card> cards;
  final bool isHero;
  final bool faceDown;

  static const double heroCardWidth = 45;
  static const double heroCardHeight = 65;
  static const double villainCardWidth = 30;
  static const double villainCardHeight = 45;
  static const double _faceAspectRatio = 50 / 70;
  static const String _cardBackAsset = 'assets/deck/cardback.png';

  const _SeatCards({
    required this.cards,
    required this.isHero,
    this.faceDown = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCard(cards[0]),
        const SizedBox(width: 2),
        _buildCard(cards[1]),
      ],
    );
  }

  Widget _buildCard(Card card) {
    double width = isHero ? heroCardWidth : villainCardWidth;
    double height = isHero ? heroCardHeight : villainCardHeight;

    // Faces and the back have different resolutions and slightly different
    // proportions, so both are stretched into the face's aspect ratio.
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: AspectRatio(
          aspectRatio: _faceAspectRatio,
          child: Image.asset(
            faceDown ? _cardBackAsset : card.assetPath,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

class _SeatLabel extends StatelessWidget {
  final String position;
  final bool isHero;

  const _SeatLabel({required this.position, required this.isHero});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isHero ? Colors.blue.shade700 : Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHero ? Colors.white : Colors.grey.shade700,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            position,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              height: 1.1,
              letterSpacing: 0.4,
            ),
          ),
          if (position == 'BTN') ...[
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFE000E0),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xAAFF00FF),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
