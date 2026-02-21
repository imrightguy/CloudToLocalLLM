/// Accessible Screen Wrapper
///
/// Wraps screens with accessibility features including:
/// - Semantic structure
/// - Keyboard navigation support
/// - Screen reader announcements
/// - Focus management
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/accessibility_service.dart';

/// Wrapper widget that adds accessibility features to screens
class AccessibleScreenWrapper extends StatefulWidget {
  /// Screen title for screen readers
  final String screenTitle;

  /// Screen description for screen readers
  final String? screenDescription;

  /// Child widget (the actual screen content)
  final Widget child;

  /// Whether to enable keyboard shortcuts
  final bool enableKeyboardShortcuts;

  /// Custom keyboard shortcuts
  final Map<LogicalKeySet, VoidCallback>? keyboardShortcuts;

  /// Whether to announce screen title on load
  final bool announceOnLoad;

  const AccessibleScreenWrapper({
    super.key,
    required this.screenTitle,
    required this.child,
    this.screenDescription,
    this.enableKeyboardShortcuts = true,
    this.keyboardShortcuts,
    this.announceOnLoad = true,
  });

  @override
  State<AccessibleScreenWrapper> createState() =>
      _AccessibleScreenWrapperState();
}

class _AccessibleScreenWrapperState extends State<AccessibleScreenWrapper> {
  final FocusNode _screenFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // Announce screen title to screen reader after build
    if (widget.announceOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _announceScreenTitle();
      });
    }
  }

  void _announceScreenTitle() {
    final accessibilityService = context.read<AccessibilityService>();
    final announcement = widget.screenDescription != null
        ? '${widget.screenTitle}. ${widget.screenDescription}'
        : widget.screenTitle;
    accessibilityService.announceToScreenReader(context, announcement);
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityService = context.watch<AccessibilityService>();

    // Build keyboard shortcuts map
    final shortcuts = <LogicalKeySet, Intent>{};
    final actions = <Type, Action<Intent>>{};

    if (widget.enableKeyboardShortcuts &&
        accessibilityService.keyboardNavigationEnabled) {
      // Add default shortcuts
      shortcuts[LogicalKeySet(LogicalKeyboardKey.escape)] =
          const _EscapeIntent();
      actions[_EscapeIntent] = CallbackAction<_EscapeIntent>(
        onInvoke: (_) {
          // Handle escape key - typically go back
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          return null;
        },
      );

      // Add custom shortcuts
      if (widget.keyboardShortcuts != null) {
        widget.keyboardShortcuts!.forEach((keySet, callback) {
          final intent = _CustomIntent(callback);
          shortcuts[keySet] = intent;
          actions[_CustomIntent] = CallbackAction<_CustomIntent>(
            onInvoke: (intent) {
              intent.callback();
              return null;
            },
          );
        });
      }
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: actions,
        child: Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          child: Semantics(
            label: widget.screenTitle,
            hint: widget.screenDescription,
            container: true,
            child: widget.child,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _screenFocusNode.dispose();
    super.dispose();
  }
}

/// Intent for escape key
class _EscapeIntent extends Intent {
  const _EscapeIntent();
}

/// Intent for custom keyboard shortcuts
class _CustomIntent extends Intent {
  final VoidCallback callback;

  const _CustomIntent(this.callback);
}

/// Accessible section widget for organizing content
class AccessibleSection extends StatelessWidget {
  /// Section title
  final String title;

  /// Section description
  final String? description;

  /// Section content
  final Widget child;

  /// Whether this is a landmark section
  final bool isLandmark;

  const AccessibleSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.isLandmark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      hint: description,
      container: true,
      header: isLandmark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Accessible list item with proper semantics
class AccessibleListItem extends StatelessWidget {
  /// Item title
  final String title;

  /// Item subtitle
  final String? subtitle;

  /// Leading widget
  final Widget? leading;

  /// Trailing widget
  final Widget? trailing;

  /// On tap callback
  final VoidCallback? onTap;

  /// Whether item is selected
  final bool selected;

  /// Whether item is enabled
  final bool enabled;

  const AccessibleListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = subtitle != null ? '$title. $subtitle' : title;

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      child: ListTile(
        leading: leading,
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
        onTap: enabled ? onTap : null,
        selected: selected,
        enabled: enabled,
        // Ensure minimum touch target size
        minVerticalPadding: 12,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
      ),
    );
  }
}

/// Accessible icon button with proper semantics
class AccessibleIconButton extends StatelessWidget {
  /// Button icon
  final IconData icon;

  /// Button label for screen readers
  final String label;

  /// Button tooltip
  final String? tooltip;

  /// On pressed callback
  final VoidCallback? onPressed;

  /// Icon size
  final double? iconSize;

  /// Icon color
  final Color? color;

  const AccessibleIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.tooltip,
    this.onPressed,
    this.iconSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: tooltip,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: IconButton(
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip: tooltip ?? label,
        iconSize: iconSize,
        color: color,
        // Ensure minimum touch target size
        constraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
      ),
    );
  }
}

/// Accessible card with proper semantics
class AccessibleCard extends StatelessWidget {
  /// Card title
  final String title;

  /// Card description
  final String? description;

  /// Card content
  final Widget child;

  /// On tap callback
  final VoidCallback? onTap;

  /// Whether card is selected
  final bool selected;

  const AccessibleCard({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = description != null ? '$title. $description' : title;

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      onTap: onTap,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (description != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    description!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
