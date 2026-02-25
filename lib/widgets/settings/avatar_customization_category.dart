import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/screens/avatar/avatar_customization_screen.dart';

/// Settings category widget for avatar customization
/// Displays avatar preview and visual customization options
class AvatarCustomizationCategory extends StatelessWidget {
  const AvatarCustomizationCategory({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.style,
                color: colorScheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avatar Appearance',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customize avatar visual appearance',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Content Card
        Card(
          elevation: 2,
          child: const Padding(
            padding: EdgeInsets.all(0),
            child: AvatarCustomizationScreen(),
          ),
        ),
      ],
    );
  }
}
