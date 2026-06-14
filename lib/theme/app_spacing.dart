import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;

  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusFull = 20.0;

  static const double radiusControl = 6.0;
  static const double radiusCard = 8.0;
  static const double radiusOverlay = 12.0;

  static BoxShadow get elevationCard => BoxShadow(
        color: Colors.black.withValues(alpha: 0.20),
        blurRadius: 8,
        offset: const Offset(0, 1),
      );

  static BoxShadow get elevationCardHover => BoxShadow(
        color: Colors.black.withValues(alpha: 0.30),
        blurRadius: 12,
        offset: const Offset(0, 2),
      );

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: AppColors.border),
      );
}
