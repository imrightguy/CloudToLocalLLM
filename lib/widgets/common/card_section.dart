import 'package:flutter/material.dart';

class CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const CardSection({
    required this.title,
    required this.children,
    this.action,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (action != null) action!,
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
