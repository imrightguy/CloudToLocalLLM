import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/platform_config.dart';

/// Widget that displays platform-specific troubleshooting guides
class PlatformTroubleshootingSection extends StatefulWidget {
  final PlatformConfig platformConfig;
  final String? currentError;
  final Function(String)? onSolutionTried;

  const PlatformTroubleshootingSection({
    super.key,
    required this.platformConfig,
    this.currentError,
    this.onSolutionTried,
  });

  @override
  State<PlatformTroubleshootingSection> createState() =>
      _PlatformTroubleshootingSectionState();
}

class _PlatformTroubleshootingSectionState
    extends State<PlatformTroubleshootingSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.platformConfig.troubleshootingGuides.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          ...widget.platformConfig.troubleshootingGuides.entries.map(
            (entry) => _buildTroubleshootingGuide(entry.key, entry.value),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: Colors.orange.shade700, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Common Issues & Solutions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                ),
                Text(
                  'Solutions for ${widget.platformConfig.displayName}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingGuide(String errorType, String solution) {
    final isCurrentError = widget.currentError == errorType;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ExpansionTile(
        initiallyExpanded: isCurrentError,
        onExpansionChanged: (expanded) {
          // Expansion state is handled by ExpansionTile internally
        },
        leading: Icon(
          isCurrentError ? Icons.error : Icons.help_outline,
          color: isCurrentError ? Colors.red : Colors.orange.shade600,
        ),
        title: Text(
          _formatErrorTitle(errorType),
          style: TextStyle(
            fontWeight: isCurrentError ? FontWeight.bold : FontWeight.normal,
            color: isCurrentError ? Colors.red.shade700 : null,
          ),
        ),
        subtitle: isCurrentError
            ? Text(
                'Current issue',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    solution,
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _markSolutionTried(errorType),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Tried This'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _getSupportForIssue(errorType),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Get Support'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatErrorTitle(String errorType) {
    return errorType
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _markSolutionTried(String errorType) {
    widget.onSolutionTried?.call(errorType);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Marked "${_formatErrorTitle(errorType)}" solution as tried',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _getSupportForIssue(String errorType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Get Support for ${_formatErrorTitle(errorType)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Need additional help with this issue?'),
            const SizedBox(height: 16),
            const Text('You can:'),
            const SizedBox(height: 8),
            const Text('• Check our documentation'),
            const Text('• Visit our GitHub issues page'),
            const Text('• Contact support directly'),
            const SizedBox(height: 16),
            Text(
              'Error Type: $errorType',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSupportLink();
            },
            child: const Text('Get Support'),
          ),
        ],
      ),
    );
  }

  /// Opens the support link in the default browser
  Future<void> _openSupportLink() async {
    const supportUrl =
        'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues/new?template=setup_issue.md&labels=setup,help-wanted';

    try {
      final uri = Uri.parse(supportUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch support URL: $supportUrl');
      }
    } catch (e) {
      debugPrint('Error opening support link: $e');
    }
  }
}
