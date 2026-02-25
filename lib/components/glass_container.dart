import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme_extensions.dart';

/// A reusable glassmorphism container.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 15,
    this.borderRadius = 16,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsTheme>()!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          margin: margin,
          decoration: BoxDecoration(
            color: colors.glassBackground,
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: colors.glassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
