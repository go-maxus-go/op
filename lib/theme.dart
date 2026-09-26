import 'package:flutter/material.dart';

@immutable
class ChartColors extends ThemeExtension<ChartColors> {
  final Color foldColor;
  final Color callColor;
  final Color raiseColor;
  final Color allInColor;
  final Color defaultColor;
  final Color pairColor;
  final Color suitedColor;
  final Color offsuitColor;

  const ChartColors({
    required this.foldColor,
    required this.callColor,
    required this.raiseColor,
    required this.allInColor,
    required this.defaultColor,
    required this.pairColor,
    required this.suitedColor,
    required this.offsuitColor,
  });

  @override
  ChartColors copyWith({
    Color? foldColor,
    Color? callColor,
    Color? raiseColor,
    Color? allInColor,
    Color? defaultColor,
    Color? pairColor,
    Color? suitedColor,
    Color? offsuitColor,
  }) {
    return ChartColors(
      foldColor: foldColor ?? this.foldColor,
      callColor: callColor ?? this.callColor,
      raiseColor: raiseColor ?? this.raiseColor,
      allInColor: allInColor ?? this.allInColor,
      defaultColor: defaultColor ?? this.defaultColor,
      pairColor: pairColor ?? this.pairColor,
      suitedColor: suitedColor ?? this.suitedColor,
      offsuitColor: offsuitColor ?? this.offsuitColor,
    );
  }

  @override
  ChartColors lerp(ThemeExtension<ChartColors>? other, double t) {
    if (other is! ChartColors) {
      return this;
    }
    return ChartColors(
      foldColor: Color.lerp(foldColor, other.foldColor, t)!,
      callColor: Color.lerp(callColor, other.callColor, t)!,
      raiseColor: Color.lerp(raiseColor, other.raiseColor, t)!,
      allInColor: Color.lerp(allInColor, other.allInColor, t)!,
      defaultColor: Color.lerp(defaultColor, other.defaultColor, t)!,
      pairColor: Color.lerp(pairColor, other.pairColor, t)!,
      suitedColor: Color.lerp(suitedColor, other.suitedColor, t)!,
      offsuitColor: Color.lerp(offsuitColor, other.offsuitColor, t)!,
    );
  }
}

class AppTheme {
  static final ColorScheme lightColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  );

  static final ColorScheme darkColorScheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.dark,
  );

  static final ChartColors lightChartColors = ChartColors(
    foldColor: Colors.grey.shade300,
    callColor: Colors.green.shade400,
    raiseColor: Colors.red.shade400,
    allInColor: Colors.blue.shade400,
    defaultColor: Colors.orange.shade400,
    pairColor: Colors.amber.shade400,
    suitedColor: Colors.green.shade400,
    offsuitColor: Colors.purple.shade400,
  );

  static final ChartColors darkChartColors = ChartColors(
    foldColor: Colors.grey.shade800,
    callColor: Colors.green,
    raiseColor: Colors.red,
    allInColor: Colors.blue,
    defaultColor: Colors.orange,
    pairColor: Colors.amber.shade800,
    suitedColor: Colors.green.shade800,
    offsuitColor: Colors.purple.shade800,
  );
}
