import 'package:flutter/material.dart';

/// Material 3 themes for the app.
abstract final class AppTheme {
  static const _seed = Colors.indigo;

  static final ThemeData light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
  );

  static final ThemeData dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
  );
}
