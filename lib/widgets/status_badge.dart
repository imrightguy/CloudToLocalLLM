import 'package:flutter/material.dart';

/// A compact status badge for cards and list items.
///
/// Displays a colored pill with label text.
/// - [StatusBadge.success] — green (paid, occupied, active)
/// - [StatusBadge.warning] — amber (pending, partial)
/// - [StatusBadge.danger] — red (overdue, vacant)
/// - [StatusBadge.info] — indigo (info, neutral)
/// - [StatusBadge.neutral] — grey (default)
enum BadgeVariant { success, warning, danger, info, neutral }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.variant = BadgeVariant.neutral,
    this.icon,
    this.outlined = false,
  });

  /// Green badge for positive states.
  const StatusBadge.success(String label, {IconData? icon, super.key})
      : label = label,
        variant = BadgeVariant.success,
        icon = icon,
        outlined = false;

  /// Amber badge for warning/attention states.
  const StatusBadge.warning(String label, {IconData? icon, super.key})
      : label = label,
        variant = BadgeVariant.warning,
        icon = icon,
        outlined = false;

  /// Red badge for negative/urgent states.
  const StatusBadge.danger(String label, {IconData? icon, super.key})
      : label = label,
        variant = BadgeVariant.danger,
        icon = icon,
        outlined = false;

  /// Indigo badge for informational states.
  const StatusBadge.info(String label, {IconData? icon, super.key})
      : label = label,
        variant = BadgeVariant.info,
        icon = icon,
        outlined = false;

  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool outlined;

  Color _backgroundColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (variant) {
      case BadgeVariant.success:
        return isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7);
      case BadgeVariant.warning:
        return isDark ? const Color(0xFF713F12) : const Color(0xFFFEF9C3);
      case BadgeVariant.danger:
        return isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
      case BadgeVariant.info:
        return isDark ? const Color(0xFF1E1B4B) : const Color(0xFFE0E7FF);
      case BadgeVariant.neutral:
        return isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6);
    }
  }

  Color _foregroundColor(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    switch (variant) {
      case BadgeVariant.success:
        return isDark ? const Color(0xFFBBF7D0) : const Color(0xFF166534);
      case BadgeVariant.warning:
        return isDark ? const Color(0xFFFDE68A) : const Color(0xFF854D0E);
      case BadgeVariant.danger:
        return isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B);
      case BadgeVariant.info:
        return isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3);
      case BadgeVariant.neutral:
        return isDark ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = _backgroundColor(brightness);
    final fg = _foregroundColor(brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(20),
        border: outlined
            ? Border.all(color: fg.withValues(alpha: 0.5), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
