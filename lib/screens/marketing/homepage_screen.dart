import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../services/platform_detection_service.dart';
import '../../services/platform_adapter.dart';
import '../../config/theme_config.dart';

/// Marketing homepage screen - web-only
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
    // Welcome message with Zoidbot persona
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
                  final uri = Uri.parse('https://app.zoidbot.online');
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
                label: 'Zoidbot Logo',
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
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'LLM',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeConfig.primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),

              // Title with proper typography
              Text(
                'Zoidbot',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: ThemeConfig.secondaryColor.withValues(alpha: 0.27),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isMobile ? 8 : 12),

              // Subtitle with responsive sizing
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8.0 : 0.0,
                ),
                child: Text(
                  'Run powerful Large Language Models locally with cloud-based management',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFe0d7ff),
                    fontWeight: FontWeight.w500,
                    fontSize: subtitleFontSize,
                    height: 1.4,
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

    // Use theme colors instead of hardcoded values
    final backgroundColor = isDark
        ? ThemeConfig.darkBackgroundMain
        : ThemeConfig.lightBackgroundMain;

    final verticalPadding = isMobile ? 24.0 : 32.0;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final cardSpacing = isMobile ? 24.0 : 40.0;

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        vertical: verticalPadding,
        horizontal: horizontalPadding,
      ),
      child: Column(
        children: [
          _buildInfoCard(context, isMobile: isMobile),
          SizedBox(height: cardSpacing),
          _buildWebAppCard(context, isMobile: isMobile),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {required bool isMobile}) {
    return _buildCard(
      context,
      isMobile: isMobile,
      title: 'What is Zoidbot?',
      description:
          'Zoidbot is an innovative platform that lets you run AI language models on your own computer while managing them through a simple cloud interface.',
      features: ['Run Models Locally', 'Cloud Management', 'Cost Effective'],
    );
  }

  Widget _buildWebAppCard(BuildContext context, {required bool isMobile}) {
    final platformService = Provider.of<PlatformDetectionService>(context);
    final platformAdapter = PlatformAdapter(platformService);

    return _buildCard(
      context,
      isMobile: isMobile,
      title: 'Web Application',
      description:
          'Access Zoidbot through your web browser with cloud streaming',
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            SizedBox(height: isMobile ? 16 : 24),
            // Use platform-appropriate button with minimum touch target size
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isMobile ? 200 : 220,
                minHeight: 44, // Minimum touch target for mobile
              ),
              child: Semantics(
                button: true,
                label: 'Launch web application',
                child: platformAdapter.buildButton(
                  onPressed: () async {
                    // Redirect to app subdomain instead of local route
                    if (kIsWeb) {
                      // Use url_launcher to navigate to app subdomain
                      final uri = Uri.parse('https://app.zoidbot.online');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, webOnlyWindowName: '_self');
                      }
                    } else {
                      // For desktop, use local routing with push to preserve stack
                      if (context.mounted) {
                        Navigator.of(context).pushNamed('/chat');
                      }
                    }
                  },
                  isPrimary: true,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: isMobile ? 12 : 14,
                      horizontal: isMobile ? 20 : 28,
                    ),
                    child: Text(
                      'Launch Web App',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required bool isMobile,
    required String title,
    required String description,
    List<String>? features,
    Widget? child,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use theme colors
    final cardColor = isDark
        ? ThemeConfig.darkBackgroundCard
        : ThemeConfig.lightBackgroundCard;
    final borderColor = isDark
        ? ThemeConfig.secondaryColor.withValues(alpha: 0.27)
        : ThemeConfig.lightBorderColor;
    final titleColor = ThemeConfig.primaryColor;
    final textColor =
        isDark ? ThemeConfig.darkTextColorLight : ThemeConfig.lightTextColor;
    final featureColor =
        isDark ? ThemeConfig.darkTextColor : ThemeConfig.lightTextColorDark;

    // Responsive sizing
    final maxWidth = isMobile ? double.infinity : 480.0;
    final cardPadding = isMobile ? 24.0 : 32.0;
    final titleFontSize = isMobile ? 18.0 : 20.0;
    final bodyFontSize = isMobile ? 14.0 : 16.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(ThemeConfig.borderRadiusM),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card title with semantic heading
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontSize: bodyFontSize,
              height: 1.5,
            ),
          ),
          if (features != null) ...[
            SizedBox(height: isMobile ? 16 : 20),
            // Feature list with semantic structure
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: features
                  .map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: featureColor,
                              fontSize: bodyFontSize,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                color: featureColor,
                                fontSize: bodyFontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (child != null) child,
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
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: const SizedBox.shrink(),
    );
  }
}
