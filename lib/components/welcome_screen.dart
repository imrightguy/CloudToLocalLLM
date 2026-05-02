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
                'Runtime channel ready',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colors.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Talk to the selected agent runtime. Local model servers stay in support roles for memory, summaries, and background tasks.',
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
                    icon: Icons.route_outlined,
                    label: 'Plan Task',
                    onTap: () => onAction('Plan the next steps for '),
                  ),
                  const SizedBox(width: 16),
                  _QuickAction(
                    icon: Icons.desktop_windows_outlined,
                    label: 'Desktop Action',
                    onTap: () => onAction(
                        'Request approval before using desktop control to '),
                  ),
                  const SizedBox(width: 16),
                  _QuickAction(
                    icon: Icons.manage_search_outlined,
                    label: 'Inspect Context',
                    onTap: () =>
                        onAction('Inspect the current context and summarize '),
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
