import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OpenClawNavItem extends StatelessWidget {
  final String title;
  final int branchIndex;
  final IconData icon;
  final bool selected;
  final bool collapsed;
  final StatefulNavigationShell navigationShell;

  const OpenClawNavItem({
    required this.title,
    required this.branchIndex,
    required this.icon,
    required this.navigationShell,
    this.selected = false,
    this.collapsed = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: title,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => navigationShell.goBranch(branchIndex),
          child: Container(
            padding: collapsed
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: collapsed
                ? Icon(
                    icon,
                    size: 20,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  )
                : Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: selected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: selected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
