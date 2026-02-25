import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../services/desktop_client_detection_service.dart';

/// Web-specific download prompt that appears for first-time web users
/// instead of the full setup wizard. Directs users to download the desktop app.
class WebDownloadPrompt extends StatefulWidget {
  final bool isFirstTimeUser;
  final VoidCallback? onDismiss;

  const WebDownloadPrompt({
    super.key,
    required this.isFirstTimeUser,
    this.onDismiss,
  });

  @override
  State<WebDownloadPrompt> createState() => _WebDownloadPromptState();
}

class _WebDownloadPromptState extends State<WebDownloadPrompt> {
  bool _isDismissed = false;

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    // Don't show if dismissed
    if (_isDismissed) {
      return const SizedBox.shrink();
    }

    return Consumer<DesktopClientDetectionService>(
      builder: (context, clientDetection, child) {
        // Don't show if clients are connected (unless it's first time user)
        if (clientDetection.hasConnectedClients && !widget.isFirstTimeUser) {
          return const SizedBox.shrink();
        }

        return _buildDownloadPrompt(context, clientDetection);
      },
    );
  }

  Widget _buildDownloadPrompt(
    BuildContext context,
    DesktopClientDetectionService clientDetection,
  ) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(AppTheme.spacingL),
          constraints: BoxConstraints(
            maxWidth: isMobile ? size.width * 0.9 : 500,
            maxHeight: size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusL),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(AppTheme.spacingL),
                decoration: BoxDecoration(
                  gradient: AppTheme.headerGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.borderRadiusL),
                    topRight: Radius.circular(AppTheme.borderRadiusL),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.download_for_offline,
                      color: Colors.white,
                      size: 32,
                    ),
                    SizedBox(width: AppTheme.spacingM),
                    Expanded(
                      child: Text(
                        'Download Desktop App',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      onPressed: _dismissPrompt,
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main message
                      Text(
                        'To use CloudToLocalLLM with your local AI models, you need to download and install the desktop application.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textColor,
                              height: 1.5,
                            ),
                      ),
                      SizedBox(height: AppTheme.spacingL),

                      // Benefits
                      _buildBenefitsList(),
                      SizedBox(height: AppTheme.spacingL),

                      // Download button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => context.go('/download'),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Desktop App'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.all(AppTheme.spacingM),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingM),

                      // Alternative action
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _dismissPrompt,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textColorLight,
                          ),
                          child: const Text('Continue without desktop app'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      'Connect to your local Ollama installation',
      'Use your own AI models privately',
      'No data sent to external servers',
      'Full control over your AI conversations',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why download the desktop app?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: AppTheme.spacingM),
        ...benefits.map(
          (benefit) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingS),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    benefit,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _dismissPrompt() {
    setState(() {
      _isDismissed = true;
    });
    widget.onDismiss?.call();
  }
}
