/// Pop-Out Button Widget
///
/// IconButton that toggles pop-out window state for Gateway sections.
/// Integrates with PopOutManager to handle window management.
///
/// Features:
/// - Toggle pop-out window on press
/// - Icon changes based on window state
/// - Tooltip shows current state
/// - Disabled when pop-out is not available for section
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../di/locator.dart' as di;
import '../../services/popout/popout_manager.dart';

/// Button widget for toggling pop-out windows
class PopOutButton extends StatelessWidget {
  /// Name of the section this button controls
  final String sectionName;

  /// Branch index for multiple instances of the same section
  final int branchIndex;

  /// Icon to display when window is closed
  final IconData? icon;

  /// Icon to display when window is open
  final IconData? activeIcon;

  /// Tooltip text when window is closed
  final String? tooltip;

  /// Tooltip text when window is open
  final String? activeTooltip;

  const PopOutButton({
    super.key,
    required this.sectionName,
    this.branchIndex = 0,
    this.icon,
    this.activeIcon,
    this.tooltip,
    this.activeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PopOutManager>.value(
      value: di.serviceLocator<PopOutManager>(),
      child: Consumer<PopOutManager>(
        builder: (context, manager, child) {
          final isWindowOpen = manager.isWindowOpen(sectionName);
          final isEnabled = manager.isSectionPopOutEnabled(sectionName);

          final selectedIcon = isWindowOpen
              ? (activeIcon ?? Icons.open_in_new)
              : (icon ?? Icons.open_in_new);

          final selectedTooltip = isWindowOpen
              ? (activeTooltip ?? 'Close pop-out window')
              : (tooltip ?? 'Open in pop-out window');

          return IconButton(
            icon: Icon(selectedIcon),
            tooltip: isEnabled ? selectedTooltip : 'Pop-out not available',
            onPressed: isEnabled
                ? () => manager.togglePopOut(sectionName, branchIndex)
                : null,
            color: isWindowOpen
                ? Theme.of(context).colorScheme.primary
                : null,
          );
        },
      ),
    );
  }
}
