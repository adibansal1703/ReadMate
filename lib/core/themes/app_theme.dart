import 'package:flutter/material.dart';
import 'package:readmate/logic/bloc/theme_bloc/theme_bloc.dart';

double get cornerRadius => _cornerRadius ?? 8;
double? _cornerRadius;

Color primaryRed = const Color(0xffB73E3E);

class AppTheme {
  static init(SetThemeState state, BuildContext context) {
    _cornerRadius = 8;
  }
}

class ThemeGetters {
  static Color getSelectionColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary.withOpacity(0.4);
}
