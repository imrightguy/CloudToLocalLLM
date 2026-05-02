import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/entrypoint_policy.dart';
import '../utils/web_navigation.dart';
import 'login_screen.dart';

class PublicEntryScreen extends StatelessWidget {
  const PublicEntryScreen({super.key, required this.location});

  final Uri location;

  static const String _appUrl = 'https://app.immogestion.app/';

  @override
  Widget build(BuildContext context) {
    if (isAppHost(location.host)) {
      return const LoginScreen();
    }

    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;

    void openApp() {
      if (kIsWeb) {
        openExternalUrl(_appUrl);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderBar(onOpenApp: openApp),
                  const SizedBox(height: 28),
                  Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _HeroPanel(
                          theme: theme,
                          onOpenApp: openApp,
                          onSignIn: openApp,
                        ),
                      ),
                      SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: const [
                            _FeatureCard(
                              icon: Icons.mark_chat_unread_outlined,
                              title: 'Messages et suivi',
                              description:
                                  'Centralisez les demandes des locataires et les échanges liés aux visites.',
                            ),
                            SizedBox(height: 16),
                            _FeatureCard(
                              icon: Icons.event_available_outlined,
                              title: 'Visites et coordination',
                              description:
                                  'Gardez les rendez-vous, les rappels et les confirmations au même endroit.',
                            ),
                            SizedBox(height: 16),
                            _FeatureCard(
                              icon: Icons.dashboard_outlined,
                              title: 'Tableau de bord clair',
                              description:
                                  'Suivez les immeubles, les unités et les tâches prioritaires d’un coup d’œil.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _DemoRail(onOpenApp: openApp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.onOpenApp});

  final VoidCallback onOpenApp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.apartment_rounded, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'ImmoGestion',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: onOpenApp,
          child: const Text('Ouvrir l’application'),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.theme,
    required this.onOpenApp,
    required this.onSignIn,
  });

  final ThemeData theme;
  final VoidCallback onOpenApp;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 30,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Démo publique',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Le point d’entrée public pour la démo ImmoGestion.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'La seule page publique. Tout le reste de la plateforme est protégé par connexion.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: onOpenApp,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Ouvrir l’application'),
              ),
              OutlinedButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Se connecter'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _MiniStatsRow(),
        ],
      ),
    );
  }
}

class _MiniStatsRow extends StatelessWidget {
  const _MiniStatsRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: const [
        _MiniStat(label: 'Messages', value: 'En un seul flux'),
        _MiniStat(label: 'Visites', value: 'Planifiées rapidement'),
        _MiniStat(label: 'Immeubles', value: 'Vue d’ensemble claire'),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoRail extends StatelessWidget {
  const _DemoRail({required this.onOpenApp});

  final VoidCallback onOpenApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0EA5A4)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chemin de démo recommandé',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ouvrez l’application, connectez-vous, puis retrouvez l’espace de travail complet derrière le mur d’authentification.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
            ),
            onPressed: onOpenApp,
            child: const Text('Ouvrir la démo'),
          ),
        ],
      ),
    );
  }
}
