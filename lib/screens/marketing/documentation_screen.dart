import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/platform_detection_service.dart';
import '../../services/platform_adapter.dart';
import '../../config/theme_config.dart';

/// Documentation screen - web-only
/// Displays documentation content with unified theme system
/// Supports responsive layout (mobile, tablet, desktop)
class DocumentationScreen extends StatelessWidget {
  const DocumentationScreen({super.key});

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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Use theme colors for proper contrast
    final backgroundColor = isDark
        ? ThemeConfig.darkBackgroundMain
        : ThemeConfig.lightBackgroundMain;
    final cardColor = isDark
        ? ThemeConfig.darkBackgroundCard
        : ThemeConfig.lightBackgroundCard;
    final borderColor = isDark
        ? ThemeConfig.secondaryColor.withValues(alpha: 0.27)
        : ThemeConfig.lightBorderColor;
    final textColor =
        isDark ? ThemeConfig.darkTextColorLight : ThemeConfig.lightTextColor;
    final iconColor = ThemeConfig.primaryColor;

    // Responsive sizing
    final maxWidth = isMobile ? double.infinity : (isTablet ? 640.0 : 800.0);
    final cardPadding = isMobile ? 24.0 : 32.0;
    final iconSize = isMobile ? 48.0 : 64.0;
    final titleFontSize = isMobile ? 24.0 : 28.0;
    final bodyFontSize = isMobile ? 14.0 : 16.0;
    final verticalSpacing = isMobile ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: verticalSpacing),
                _buildMainCard(
                  context,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  iconColor: iconColor,
                  cardPadding: cardPadding,
                  iconSize: iconSize,
                  titleFontSize: titleFontSize,
                  bodyFontSize: bodyFontSize,
                  verticalSpacing: verticalSpacing,
                  isMobile: isMobile,
                  isDark: isDark,
                ),
                SizedBox(height: verticalSpacing),
                _buildResourcesCard(
                  context,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  cardPadding: cardPadding,
                  titleFontSize: titleFontSize - 4,
                  bodyFontSize: bodyFontSize,
                  verticalSpacing: verticalSpacing,
                  isMobile: isMobile,
                  isDark: isDark,
                ),
                SizedBox(height: verticalSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCard(
    BuildContext context, {
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color iconColor,
    required double cardPadding,
    required double iconSize,
    required double titleFontSize,
    required double bodyFontSize,
    required double verticalSpacing,
    required bool isMobile,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final platformService = Provider.of<PlatformDetectionService>(context);
    final platformAdapter = PlatformAdapter(platformService);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(ThemeConfig.borderRadiusM),
        border: Border.all(color: borderColor, width: 1.5),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon with semantic label
          Semantics(
            label: 'Documentation icon',
            child: Icon(
              Icons.menu_book,
              size: iconSize,
              color: iconColor,
            ),
          ),
          SizedBox(height: verticalSpacing),

          // Title with semantic heading
          Semantics(
            header: true,
            child: Text(
              'Documentation Coming Soon',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
                color: textColor,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: verticalSpacing / 2),

          // Description with proper typography and contrast
          Text(
            'We\'re refreshing the in-app documentation experience. In the meantime, '
            'visit our GitHub repository for the latest guides and release notes.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: textColor,
              fontSize: bodyFontSize,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: verticalSpacing),

          // Back button with platform-appropriate styling and minimum touch target
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isMobile ? 120 : 140,
              minHeight: 44, // Minimum touch target for mobile
            ),
            child: Semantics(
              button: true,
              label: 'Go back to previous page',
              child: platformAdapter.buildButton(
                onPressed: () => Navigator.of(context).maybePop(),
                isPrimary: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 12 : 14,
                    horizontal: isMobile ? 16 : 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: bodyFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcesCard(
    BuildContext context, {
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required double cardPadding,
    required double titleFontSize,
    required double bodyFontSize,
    required double verticalSpacing,
    required bool isMobile,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final platformService = Provider.of<PlatformDetectionService>(context);
    final platformAdapter = PlatformAdapter(platformService);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(ThemeConfig.borderRadiusM),
        border: Border.all(color: borderColor, width: 1.5),
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
          // Section title with semantic heading
          Semantics(
            header: true,
            child: Text(
              'Available Resources',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
                color: textColor,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(height: verticalSpacing),

          // GitHub repository link
          _buildResourceLink(
            context,
            icon: Icons.code,
            title: 'GitHub Repository',
            description: 'View source code, issues, and contribute',
            url: 'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM',
            textColor: textColor,
            bodyFontSize: bodyFontSize,
            verticalSpacing: verticalSpacing,
            isMobile: isMobile,
            platformAdapter: platformAdapter,
          ),
          SizedBox(height: verticalSpacing),

          // Release notes link
          _buildResourceLink(
            context,
            icon: Icons.new_releases,
            title: 'Release Notes',
            description: 'Latest updates and changelog',
            url:
                'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases',
            textColor: textColor,
            bodyFontSize: bodyFontSize,
            verticalSpacing: verticalSpacing,
            isMobile: isMobile,
            platformAdapter: platformAdapter,
          ),
        ],
      ),
    );
  }

  Widget _buildResourceLink(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required String url,
    required Color textColor,
    required double bodyFontSize,
    required double verticalSpacing,
    required bool isMobile,
    required PlatformAdapter platformAdapter,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: ThemeConfig.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  fontSize: bodyFontSize + 2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: textColor,
              fontSize: bodyFontSize - 1,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: isMobile ? 100 : 120,
              minHeight: 44, // Minimum touch target for mobile
            ),
            child: Semantics(
              button: true,
              label: 'Open $title in browser',
              link: true,
              child: platformAdapter.buildButton(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                isPrimary: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: isMobile ? 8 : 10,
                    horizontal: isMobile ? 12 : 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_new, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Visit',
                        style: TextStyle(
                          fontSize: bodyFontSize - 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
