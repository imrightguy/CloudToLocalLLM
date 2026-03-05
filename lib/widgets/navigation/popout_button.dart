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

  const PopOutButton({
    super.key,
    required this.sectionName,
    this.branchIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PopOutManager>.value(
      value: di.serviceLocator<PopOutManager>(),
      child: Consumer<PopOutManager>(
        builder: (context, manager, child) {
          return IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Toggle pop-out window',
            onPressed: () => manager.togglePopOut(sectionName, branchIndex),
          );
        },
      ),
    );
  }
}
