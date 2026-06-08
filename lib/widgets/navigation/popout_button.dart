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

  /// Optional manager override (useful for testing without GetIt registration)
  final PopOutManager? manager;

  const PopOutButton({
    super.key,
    required this.sectionName,
    this.branchIndex = 0,
    this.manager,
  });

  @override
  Widget build(BuildContext context) {
    final popOutManager = manager ?? _tryResolveFromGetIt();
    if (popOutManager == null) {
      // GetIt not configured (e.g. in tests) — render a no-op button
      return IconButton(
        icon: const Icon(Icons.open_in_new),
        tooltip: 'Toggle pop-out window',
        onPressed: null,
      );
    }

    return ChangeNotifierProvider<PopOutManager>.value(
      value: popOutManager,
      child: Consumer<PopOutManager>(
        builder: (context, mgr, child) {
          return IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Toggle pop-out window',
            onPressed: () => mgr.togglePopOut(sectionName, branchIndex),
          );
        },
      ),
    );
  }

  /// Attempt to resolve PopOutManager from GetIt; return null if not registered.
  PopOutManager? _tryResolveFromGetIt() {
    try {
      return di.serviceLocator<PopOutManager>();
    } catch (_) {
      return null;
    }
  }
}
