import 'package:flutter/material.dart';

const _kSeedBlue = Color(0xFF3F6FB0);
const _kBone = Color(0xFFF4EEE2);
const _kGoldAccent = Color(0xFFE0A33C);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: _kSeedBlue,
    surface: _kBone,
  ).copyWith(secondary: _kGoldAccent),
  scaffoldBackgroundColor: _kBone,
);
