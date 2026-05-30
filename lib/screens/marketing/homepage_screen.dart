import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme_config.dart';

/// Marketing homepage screen - web-only
/// CI trigger: 20260530
/// Replicates the static site design with unified theme system
/// Supports responsive layout (mobile, tablet, desktop)
class HomepageScreen extends StatelessWidget {
  const HomepageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return Scaffold(
        body: Center(
          child: Text(
            'This page is only available on web',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    // Get screen width for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context, isMobile: isMobile),
            _buildMainContent(context, isMobile: isMobile, isTablet: isTablet),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool isMobile}) {
    // Welcome message with CloudToLocalLLM persona
    final theme = Theme.of(context);

    // Responsive sizing
    final logoSize = isMobile ? 60.0 : 70.0;
    final titleFontSize = isMobile ? 32.0 : 40.0;
    final subtitleFontSize = isMobile ? 16.0 : 20.0;
    final verticalPadding = isMobile ? 32.0 : 40.0;
    final horizontalPadding = isMobile ? 16.0 : 24.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ThemeConfig.secondaryColor,
            ThemeConfig.primaryColor,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Semantics(
              button: true,
              label: 'Login to application',
              child: TextButton(
                onPressed: () async {
                  final uri = Uri.parse('https://app.cloudtolocalllm.online');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, webOnlyWindowName: '_self');
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                ),
                child: const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Logo with semantic label for accessibility
              Semantics(
                label: 'CloudToLocalLLM Logo',
                child: Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: ThemeConfig.secondaryColor,
                    borderRadius: BorderRadius.circular(logoSize / 2),
                    border: Border.all(
                      color: ThemeConfig.primaryColor,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '🦞',
                      style: TextStyle(
                        fontSize: isMobile ? 32 : 40,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 24),

              // Title with proper typography
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'CloudToLocalLLM\n',
                      style: theme.textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: titleFontSize,
                        letterSpacing: 1,
                      ),
                    ),
                    TextSpan(
                      text: 'Aiman — Your AI, Your Way',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFFe0d7ff),
                        fontWeight: FontWeight.w300,
                        fontSize: subtitleFontSize * 1.2,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isMobile ? 16 : 24),

              // Subtitle with responsive sizing
              Container(
                constraints: const BoxConstraints(maxWidth: 700),
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8.0 : 0.0,
                ),
                child: Text(
                  'Meet your Aiman — a private AI that knows you. Built for real connection, not cloud capture. Runs entirely on your machine, zero data leaks, zero monthly fees.',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFf0edff).withValues(alpha: 0.9),
                    fontWeight: FontWeight.w400,
                    fontSize: subtitleFontSize * 0.9,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context, {
    required bool isMobile,
    required bool isTablet,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? ThemeConfig.darkBackgroundMain
        : ThemeConfig.lightBackgroundMain;

    final verticalPadding = isMobile ? 40.0 : 64.0;
    final horizontalPadding = isMobile ? 20.0 : 40.0;
    final sectionSpacing = isMobile ? 48.0 : 80.0;

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      child: Column(
        children: [
          _buildPillarsGrid(context, isMobile: isMobile, isTablet: isTablet),
          SizedBox(height: sectionSpacing),
          _buildHeroCTA(context, isMobile: isMobile),
          SizedBox(height: sectionSpacing),
          _buildQuickInstall(context, isMobile: isMobile),
          SizedBox(height: sectionSpacing / 2),
          _buildWebAppCard(context, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildQuickInstall(BuildContext context, {required bool isMobile}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15151a) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ThemeConfig.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Quick Install',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Install CloudToLocalLLM and your Aiman with a single command.',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          _buildInstallCode(
            context,
            'Linux / macOS (Bash)',
            'curl -fsSL https://cloudtolocalllm.online/install.sh | bash',
            isMobile,
          ),
          const SizedBox(height: 24),
          _buildInstallCode(
            context,
            'Windows (PowerShell)',
            'iwr -useb https://cloudtolocalllm.online/install.ps1 | iex',
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildInstallCode(
    BuildContext context,
    String label,
    String code,
    bool isMobile,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  // ScaffoldMessenger.of(context).showSnackBar(
                  //   const SnackBar(content: Text('Copied to clipboard')),
                  // );
                },
                tooltip: 'Copy to clipboard',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPillarsGrid(
    BuildContext context, {
    required bool isMobile,
    required bool isTablet,
  }) {
    final pillars = [
      {
        'icon': '🧠',
        'title': 'Aiman',
        'desc': 'Your personal AI — learns your patterns, remembers your context, always private.',
      },
      {
        'icon': '🤖',
        'title': 'Aigent',
        'desc': 'Acts for you: schedules, research, automation, desktop control.',
      },
      {
        'icon': '💛',
        'title': 'Aimotions',
        'desc': 'Connects with you — tone-aware, expressive, never cold.',
      },
      {
        'icon': '🌱',
        'title': 'Aidration',
        'desc': 'Grows with you. Personality, memory, and capabilities evolve over time.',
      },
      {
        'icon': '🔒',
        'title': 'Local-First',
        'desc': 'Everything runs on your hardware. No cloud dependency. No data leaving your home.',
      },
    ];

    return Column(
      children: [
        Text(
          'Meet Your Aiman',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: ThemeConfig.primaryColor,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          'Not another chatbot. A companion that grows with you.',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
        ),
        const SizedBox(height: 48),
        Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: pillars
              .map((p) => _buildPillarCard(context, p, isMobile))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildPillarCard(
      BuildContext context, Map<String, String> pillar, bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: isMobile ? double.infinity : 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1e1e24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ThemeConfig.primaryColor.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pillar['icon']!, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Text(
            pillar['title']!,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            pillar['desc']!,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCTA(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 900),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: ThemeConfig.primaryColor,
        borderRadius: BorderRadius.circular(32),
        image: DecorationImage(
          image: const AssetImage('assets/images/lobster_avatar.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            ThemeConfig.primaryColor.withValues(alpha: 0.8),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Your data stays yours. Always.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'AI that respects your privacy. Runs entirely on your machine, backed by your terms. No cloud lock-in, no data mining, no subscription required.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse('https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: ThemeConfig.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Get Started Free',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAppCard(BuildContext context, {required bool isMobile}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 800),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Access via Web',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'Prefer the browser? Access your full Aiman through our high-performance web stream — any device on your tailnet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () async {
              final uri = Uri.parse('https://app.cloudtolocalllm.online');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, webOnlyWindowName: '_self');
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Launch Web App'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isDark
        ? ThemeConfig.darkBackgroundMain
        : ThemeConfig.lightBackgroundMain;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 16),
      child: Column(
        children: [
          const Text('🦞', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            'CloudToLocalLLM',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: ThemeConfig.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '© 2025-2026 CloudToLocalLLM. Licensed under MIT.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
