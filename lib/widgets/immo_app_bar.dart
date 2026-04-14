import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ImmoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ImmoAppBar({
    super.key,
    required this.title,
    this.centerTitle = true,
    this.actions,
    this.leading,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.titleTextStyle,
  });

  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final TextStyle? titleTextStyle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: centerTitle,
      elevation: 0,
      backgroundColor: backgroundColor ?? AppColors.surface,
      foregroundColor: foregroundColor ?? AppColors.textPrimary,
      surfaceTintColor: backgroundColor ?? AppColors.surface,
      leading: leading,
      actions: actions,
      bottom: bottom,
      titleTextStyle: titleTextStyle ??
          const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
    );
  }
}
