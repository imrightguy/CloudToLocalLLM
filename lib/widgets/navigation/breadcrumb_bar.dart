import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Breadcrumb widget showing navigation path
///
/// Usage:
/// ```dart
/// BreadcrumbBar(
///   items: [
///     BreadcrumbItem(label: 'Home', route: '/'),
///     BreadcrumbItem(label: 'Settings', route: '/settings'),
///     BreadcrumbItem(label: 'Connection', route: '/settings/connection'),
///   ],
/// )
/// ```
class BreadcrumbBar extends StatelessWidget {
  final List<BreadcrumbItem> items;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const BreadcrumbBar({
    super.key,
    required this.items,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: backgroundColor ?? colorScheme.surfaceContainerLow,
      child: Wrap(
        spacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: _buildBreadcrumbs(context, colorScheme),
      ),
    );
  }

  List<Widget> _buildBreadcrumbs(
      BuildContext context, ColorScheme colorScheme) {
    final List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      // Breadcrumb item
      widgets.add(
        _BreadcrumbChip(
          label: item.label,
          isLast: isLast,
          isActive: item.isActive ?? false,
          onTap: item.route != null && !isLast
              ? () => _navigate(context, item.route!)
              : null,
        ),
      );

      // Separator (chevron)
      if (!isLast) {
        widgets.add(
          Icon(
            Icons.chevron_right,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }
    }

    return widgets;
  }

  void _navigate(BuildContext context, String route) {
    context.go(route);
  }
}

/// Breadcrumb item data class
class BreadcrumbItem {
  final String label;
  final String? route;
  final bool? isActive;

  const BreadcrumbItem({
    required this.label,
    this.route,
    this.isActive,
  });

  BreadcrumbItem copyWith({String? label, String? route, bool? isActive}) {
    return BreadcrumbItem(
      label: label ?? this.label,
      route: route ?? this.route,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Internal breadcrumb chip widget
class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final bool isLast;
  final bool isActive;
  final VoidCallback? onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.isLast,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLast && !isActive)
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              )
            else if (isActive)
              Icon(
                Icons.folder_open,
                size: 14,
                color: colorScheme.primary,
              ),
            SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? colorScheme.primary : colorScheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper to build breadcrumbs from current GoRouter location
class AutoBreadcrumbBar extends StatelessWidget {
  const AutoBreadcrumbBar({super.key});

  static final _routeMap = <String, List<BreadcrumbItem>>{
    '/': [
      BreadcrumbItem(label: 'Home', route: '/'),
    ],
    '/settings': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Settings'),
    ],
    '/settings/general': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'General'),
    ],
    '/settings/appearance': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'Appearance'),
    ],
    '/settings/connection': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'Connection'),
    ],
    '/settings/avatar': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'Avatar'),
    ],
    '/settings/desktop': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'Desktop'),
    ],
    '/settings/about': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'About'),
    ],
    '/settings/daemon': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Connection', route: '/settings/connection'),
      const BreadcrumbItem(label: 'Daemon Settings'),
    ],
    '/settings/connection-status': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Connection', route: '/settings/connection'),
      const BreadcrumbItem(label: 'Connection Status'),
    ],
    '/settings/avatar/customization': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Avatar', route: '/settings/avatar'),
      const BreadcrumbItem(label: 'Customization'),
    ],
    '/settings/desktop/files': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Desktop', route: '/settings/desktop'),
      const BreadcrumbItem(label: 'File Operations'),
    ],
    '/upgrade': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'About', route: '/settings/about'),
      const BreadcrumbItem(label: 'Upgrade'),
    ],
    '/settings/downloads': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      const BreadcrumbItem(label: 'Downloads'),
    ],
    '/settings/tunnel': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Connection', route: '/settings/connection'),
      const BreadcrumbItem(label: 'Tunnel Settings'),
    ],
    '/dashboard': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Dashboard'),
    ],
    '/overview': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Overview'),
    ],
    '/agents': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Agents'),
    ],
    '/gui-automation': [
      BreadcrumbItem(label: 'Home', route: '/'),
      BreadcrumbItem(label: 'Settings', route: '/settings'),
      BreadcrumbItem(label: 'Desktop', route: '/settings/desktop'),
      const BreadcrumbItem(label: 'GUI Automation'),
    ],
    '/agent-status': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Agent Status'),
    ],
    '/brain-insights': [
      BreadcrumbItem(label: 'Home', route: '/'),
      const BreadcrumbItem(label: 'Brain Insights'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final breadcrumbs = _routeMap[location];

    if (breadcrumbs == null || breadcrumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Mark last item as active
    final items = breadcrumbs.map((item) {
      return item.copyWith(
        isActive: item == breadcrumbs.last,
      );
    }).toList();

    return BreadcrumbBar(items: items);
  }
}
