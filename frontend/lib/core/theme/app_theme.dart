import 'package:flutter/material.dart';

const _kSeedBlue = Color(0xFF3F6FB0);
const _kBone = Color(0xFFF4EEE2);
const _kGoldAccent = Color(0xFFE0A33C);

// La barra de desplazamiento vertical va siempre visible, con su pista, para
// que se note que se puede deslizar. El pulgar contrasta 5,23 a 1 con el
// hueso (WCAG pide 3 a 1 para elementos gráficos) y la pista apenas más
// oscura que el fondo. `AppScrollBehavior` la dibuja en todas las plataformas.
const _kScrollbarThumb = Color(0xFF5C6370);
const _kScrollbarTrack = Color(0xFFE3DBCB);

final ScrollbarThemeData _scrollbarTheme = ScrollbarThemeData(
  thumbVisibility: WidgetStateProperty.all(true),
  trackVisibility: WidgetStateProperty.all(true),
  thickness: WidgetStateProperty.all(10),
  radius: const Radius.circular(5),
  thumbColor: WidgetStateProperty.all(_kScrollbarThumb),
  trackColor: WidgetStateProperty.all(_kScrollbarTrack),
  trackBorderColor: WidgetStateProperty.all(_kScrollbarTrack),
  crossAxisMargin: 0,
  interactive: true,
);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _kSeedBlue,
    surface: _kBone,
  ).copyWith(secondary: _kGoldAccent),
  scaffoldBackgroundColor: _kBone,
  scrollbarTheme: _scrollbarTheme,
);
