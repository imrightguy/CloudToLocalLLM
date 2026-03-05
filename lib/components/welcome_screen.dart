import 'package:flutter/material.dart';
import '../config/theme_extensions.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onNewChat;
  final Function(String) onAction;

  const WelcomeScreen({
    super.key,
    required this.onNewChat,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsTheme>()!;
    final theme = Theme.of(context);

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            // Logo or Icon with Glow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Hero(
                tag: 'app_logo',
                child: Icon(
                  Icons.auto_awesome,
                  size: 80,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Welcome back!',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'What can I help you with today? I am your personal AI assistant, ready to explore local or cloud LLMs with you.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.textColorLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // Quick Action Cards
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuickAction(
                  icon: Icons.lightbulb_outline,
                  label: 'Explain Code',
                  onTap: () => onAction('Explain how this code works: '),
                ),
                const SizedBox(width: 16),
                _QuickAction(
                  icon: Icons.edit_note,
                  label: 'Write Story',
                  onTap: () => onAction('Write a short story about '),
                ),
                const SizedBox(width: 16),
                _QuickAction(
                  icon: Icons.science_outlined,
                  label: 'Research',
                  onTap: () =>
                      onAction('Research and summarize information about '),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsTheme>()!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.secondary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
