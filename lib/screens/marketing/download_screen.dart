import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/github_release_service.dart';

/// Download screen - web-only marketing page
/// Comprehensive installation guide for Linux distributions
class DownloadScreen extends StatelessWidget {
  const DownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show on web platform
    if (!kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('This page is only available on web')),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildMainContent(context),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6e8efb), Color(0xFFa777e3)],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          // Logo
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF6e8efb),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: const Color(0xFFa777e3), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'LLM',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFa777e3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Download CloudToLocalLLM',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 40,
                  letterSpacing: 1,
                ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Complete installation guide for Linux distributions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFe0d7ff),
                  fontWeight: FontWeight.w500,
                  fontSize: 20,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Back link
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text(
              '← Back to Home',
              style: TextStyle(
                color: Color(0xFFa777e3),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      color: const Color(0xFF181a20),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          _buildDownloadButtons(context),
          const SizedBox(height: 40),
          _buildSystemRequirements(context),
          const SizedBox(height: 40),
          _buildSnapPackage(context),
          const SizedBox(height: 40),
          _buildDebianPackage(context),
          const SizedBox(height: 40),
          _buildAppImage(context),
          const SizedBox(height: 40),
          _buildAURPackage(context),
          const SizedBox(height: 40),
          _buildPrebuiltBinary(context),
          const SizedBox(height: 40),
          _buildGettingStarted(context),
        ],
      ),
    );
  }

  Widget _buildDownloadButtons(BuildContext context) {
    return _buildCard(
      context,
      title: '� Quick Downloads',
      description:
          'Download the latest version of CloudToLocalLLM for your platform',
      child: Column(
        children: [
          const SizedBox(height: 24),

          // Primary GitHub Releases button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchUrl(AppConfig.githubReleasesUrl, context),
              icon: const Icon(Icons.download),
              label: const Text('View All Downloads on GitHub'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6e8efb),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 24,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Platform-specific download buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadFile(
                    'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/CloudToLocalLLM-Windows-${AppConfig.appVersion}-Setup.exe',
                    'CloudToLocalLLM-Windows-${AppConfig.appVersion}-Setup.exe',
                    context,
                  ),
                  icon: const Icon(Icons.desktop_windows),
                  label: const Text('Windows Installer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00c58e),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _downloadFile(
                    'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-portable.zip',
                    'CloudToLocalLLM-${AppConfig.appVersion}-portable.zip',
                    context,
                  ),
                  icon: const Icon(Icons.archive),
                  label: const Text('Windows Portable'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFa777e3),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info text
          const Text(
            'For Linux and macOS downloads, visit the GitHub releases page above.',
            style: TextStyle(color: Color(0xFFb0b0b0), fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemRequirements(BuildContext context) {
    return _buildCard(
      context,
      title: 'System Requirements',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00c58e).withValues(alpha: 0.1),
          border: Border.all(
            color: const Color(0xFF00c58e).withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Minimum Requirements:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'OS: Any modern Linux distribution (kernel 4.15+)',
              'Architecture: x86_64 (64-bit)',
              'Memory: 512MB RAM minimum, 1GB recommended',
              'Storage: 200MB available space',
              'Desktop: GNOME, KDE Plasma, XFCE, or compatible',
            ].map(
              (req) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $req',
                  style: const TextStyle(color: Color(0xFFf1f1f1)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'For System Tray Support:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Required: libayatana-appindicator',
              'GNOME Users: AppIndicator extension recommended',
              'Tiling WMs: Status bar with system tray support',
            ].map(
              (req) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $req',
                  style: const TextStyle(color: Color(0xFFf1f1f1)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapPackage(BuildContext context) {
    return _buildCard(
      context,
      title: '� Snap Package (Universal)',
      description:
          'Universal Linux package with automatic updates and sandboxed security. Works on most Linux distributions.',
      child: _buildInstallationSection(
        'Installation from Snap Store (Coming Soon)',
        '''# Install from Snap Store (when available)
sudo snap install CloudToLocalLLM

# Enable system tray access
sudo snap connect CloudToLocalLLM:system-observe''',
      ),
    );
  }

  Widget _buildDebianPackage(BuildContext context) {
    return _buildCard(
      context,
      title: '� Debian Package (.deb)',
      description:
          'Native package for Ubuntu, Debian, and derivatives with proper dependency management.',
      child: _buildInstallationSection(
        'Installation',
        '''# Download from GitHub releases
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm_${AppConfig.appVersion}_amd64.deb

# Install with dpkg
sudo dpkg -i cloudtolocalllm_${AppConfig.appVersion}_amd64.deb

# Install dependencies if needed
sudo apt-get install -f''',
      ),
    );
  }

  Widget _buildAppImage(BuildContext context) {
    return _buildCard(
      context,
      title: '� AppImage (Portable)',
      description:
          'Portable application that runs on any Linux distribution without installation. No root access required.',
      child: _buildInstallationSection(
        'Download and Run',
        '''# Download AppImage from GitHub releases
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage

# Make executable
chmod +x CloudToLocalLLM-${AppConfig.appVersion}-x86_64.AppImage

# Run directly
./cloudtolocalllm-${AppConfig.appVersion}-x86_64.AppImage''',
      ),
    );
  }

  Widget _buildAURPackage(BuildContext context) {
    return _buildCard(
      context,
      title: '� Arch User Repository (AUR)',
      description:
          'Pre-built binary package for Arch Linux and derivatives. No Flutter dependency required!',
      child: _buildInstallationSection(
        'Installation with AUR Helper (Recommended)',
        '''# Install with yay (no build dependencies needed)
yay -S CloudToLocalLLM

# Or using paru
paru -S CloudToLocalLLM

# Or using pamac
pamac install CloudToLocalLLM''',
      ),
    );
  }

  Widget _buildPrebuiltBinary(BuildContext context) {
    return _buildCard(
      context,
      title: '⚡ Pre-built Binary (Universal)',
      description:
          'Direct download of the compiled application for manual installation on any Linux distribution.',
      child: _buildInstallationSection(
        'Download and Install',
        '''# Download pre-built binary from GitHub releases
wget https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest/download/cloudtolocalllm-${AppConfig.appVersion}-x86_64.tar.gz

# Extract to local directory
tar -xzf CloudToLocalLLM-${AppConfig.appVersion}-x86_64.tar.gz
cd CloudToLocalLLM-${AppConfig.appVersion}-x86_64

# Run directly
./CloudToLocalLLM''',
      ),
    );
  }

  Widget _buildGettingStarted(BuildContext context) {
    return _buildCard(
      context,
      title: ' Getting Started',
      description: 'Quick setup guide after installation.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            '1. Launch the Application',
            style: TextStyle(
              color: Color(0xFFa777e3),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'CloudToLocalLLM will minimize to the system tray by default. Look for the LLM icon in your system tray.',
            style: TextStyle(color: Color(0xFFb0b0b0)),
          ),
          const SizedBox(height: 16),
          const Text(
            '2. Configure LLM Provider',
            style: TextStyle(
              color: Color(0xFFa777e3),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Go to Settings → LLM Provider Settings to configure your connection:',
            style: TextStyle(color: Color(0xFFb0b0b0)),
          ),
          const SizedBox(height: 8),
          ...[
            'Desktop: Configure direct localhost:11434 connection to Ollama',
            'Web: Uses CloudToLocalLLM streaming proxy automatically',
          ].map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $item',
                style: const TextStyle(color: Color(0xFFb0b0b0)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required String title,
    String? description,
    required Widget child,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: const Color(0xFF23243a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6e8efb).withValues(alpha: 0.27),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFa777e3),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFb0b0b0),
                    fontSize: 16,
                  ),
            ),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildInstallationSection(String title, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFFa777e3),
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              color: Color(0xFF00c58e),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      color: const Color(0xFF181a20),
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Center(
        child: TextButton(
          onPressed: () => context.go('/'),
          child: const Text(
            '← Back to Home',
            style: TextStyle(
              color: Color(0xFFa777e3),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  /// Launch URL in external browser with improved error handling
  Future<void> _launchUrl(String url, [BuildContext? context]) async {
    // Show loading indicator for download attempts before async operations
    if (url.contains('/download/') && context != null) {
      _showDownloadStartedMessage(context);
    }

    try {
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('Successfully launched URL: $url');
      } else {
        debugPrint('Could not launch URL: $url');
        // Use a post-frame callback to avoid async context issues
        if (context != null && context.mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              _showErrorMessage(
                context,
                'Unable to open download link. Please try again or visit GitHub releases page directly.',
              );
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      // Use a post-frame callback to avoid async context issues
      if (context != null && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            _showErrorMessage(
              context,
              'Download failed. Please check your internet connection and try again.',
            );
          }
        });
      }
    }
  }

  /// Download file using appropriate method for the platform
  Future<void> _downloadFile(
    String downloadUrl,
    String fileName,
    BuildContext context,
  ) async {
    try {
      final releaseService = GitHubReleaseService();
      await releaseService.downloadFile(downloadUrl, fileName);
      if (context.mounted) {
        _showDownloadStartedMessage(context);
      }
    } catch (e) {
      debugPrint('Download failed: $e');
      if (context.mounted) {
        _showErrorMessage(
          context,
          'Download failed. Please try again or visit GitHub releases page directly.',
        );
      }
    }
  }

  /// Show download started message
  void _showDownloadStartedMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.download, color: Colors.white),
            SizedBox(width: 8),
            Text('Download started...'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Show error message
  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'GitHub Releases',
          textColor: Colors.white,
          onPressed: () => _launchUrl(AppConfig.githubReleasesUrl),
        ),
      ),
    );
  }
}
