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

class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1400;

  // Card sizing constraints
  static const double cardMinWidth = 280;
  static const double cardMaxWidth = 360;
  static const double cardGridGap = 12;
}

class Responsive {
  Responsive._();

  /// Max content width for the page (prevents ultrawide stretching)
  static const double maxContentWidth = 1200;

  /// Returns the number of grid columns based on available width
  static int gridColumns(double width) {
    if (width < AppBreakpoints.mobile) return 1;
    if (width < AppBreakpoints.tablet) return 2;
    if (width < 800) return 2;
    if (width < 1000) return 3;
    return 4;
  }

  /// Returns the number of stat card columns based on available width
  static int statColumns(double width) {
    if (width < 480) return 1;
    if (width < AppBreakpoints.mobile) return 2;
    return 4;
  }

  /// Page horizontal padding
  static double pagePadding(double width) {
    if (width < AppBreakpoints.mobile) return 16;
    if (width < AppBreakpoints.tablet) return 24;
    return 32;
  }

  /// Whether card should be full-width or constrained
  static bool isFullWidthCard(double width) => width < 480;
}
