import 'package:flutter/material.dart';

import '../core/theme/app_colour_theme.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: false,
    primaryColor: AppColors.primaryRed,
    fontFamily: 'sans-serif',
  );
}
