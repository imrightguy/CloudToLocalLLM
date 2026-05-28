import 'package:flutter/material.dart';

/// Welcome step - First screen of the setup wizard
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar/Icon
          _AvatarCircle(),
          SizedBox(height: 32),

          // Title
          _TitleText(),
          SizedBox(height: 16),

          // Subtitle
          _SubtitleText(),
          SizedBox(height: 32),

          // Feature cards
          _FeatureCards(),
          SizedBox(height: 32),

          // Info text
          _InfoBox(),
          SizedBox(height: 24),

          // Skip option (small)
          _SkipButton(),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.rocket_launch,
        size: 64,
        color: Theme.of(context).primaryColor,
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  const _TitleText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Welcome to CloudToLocalLLM',
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _SubtitleText extends StatelessWidget {
  const _SubtitleText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your privacy-first local AI companion',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.grey.shade600,
          ),
      textAlign: TextAlign.center,
    );
  }
}

class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 16,
      children: [
        _FeatureCard(
          icon: Icons.chat_bubble_outline,
          title: 'Chat',
          description: 'Streaming AI responses',
        ),
        _FeatureCard(
          icon: Icons.hub_outlined,
          title: 'Agent Runtimes',
          description: 'Hermes, OpenClaw, and compatible gateways',
        ),
        _FeatureCard(
          icon: Icons.face_outlined,
          title: 'Evolving Avatar',
          description: 'Personalized AI companion',
        ),
        _FeatureCard(
          icon: Icons.desktop_windows_outlined,
          title: 'Desktop Control',
          description: 'GUI automation',
        ),
        _FeatureCard(
          icon: Icons.visibility_outlined,
          title: 'Vision',
          description: 'Screen understanding',
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We\'ll set up your local AI in about 2 minutes. All processing happens privately on your computer.',
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        // Future enhancement: Check returning user status to allow skip
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setup is required for first-time users'),
          ),
        );
      },
      child: const Text('Already configured?'),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
