/// Enhanced Error Handler for Zoidbot
///
/// This component provides comprehensive error handling and user feedback including:
/// - User-friendly error messages with context
/// - Troubleshooting guidance and suggestions
/// - Diagnostic tools and system information
/// - Recovery actions and retry mechanisms
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/llm_communication_error.dart';
import '../config/theme.dart';
import '../services/connection_manager_service.dart';
import '../services/llm_provider_manager.dart';
import '../services/provider_discovery_service.dart';

/// Enhanced error display widget with troubleshooting guidance
class EnhancedErrorWidget extends StatefulWidget {
  final LLMCommunicationError error;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool showDiagnostics;
  final bool showTroubleshooting;

  const EnhancedErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.onDismiss,
    this.showDiagnostics = true,
    this.showTroubleshooting = true,
  });

  @override
  State<EnhancedErrorWidget> createState() => _EnhancedErrorWidgetState();
}

class _EnhancedErrorWidgetState extends State<EnhancedErrorWidget> {
  bool _showDetails = false;
  bool _showDiagnostics = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(AppTheme.spacingM),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildErrorHeader(),
            SizedBox(height: AppTheme.spacingM),
            _buildErrorMessage(),
            if (widget.showTroubleshooting) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildTroubleshootingSection(),
            ],
            if (_showDetails) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildErrorDetails(),
            ],
            if (_showDiagnostics && widget.showDiagnostics) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildDiagnosticsSection(),
            ],
            SizedBox(height: AppTheme.spacingL),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorHeader() {
    final errorIcon = _getErrorIcon(widget.error.type);
    final errorColor = _getErrorColor(widget.error.type);

    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: errorColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(errorIcon, color: errorColor, size: 24),
        ),
        SizedBox(width: AppTheme.spacingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getErrorTitle(widget.error.type),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (widget.error.providerId != null) ...[
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  'Provider: ${widget.error.providerId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (widget.onDismiss != null)
          IconButton(
            onPressed: widget.onDismiss,
            icon: Icon(Icons.close, color: AppTheme.textColorLight),
          ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getUserFriendlyMessage(widget.error),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (widget.error.context?.isNotEmpty == true) ...[
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Context: ${widget.error.context}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSection() {
    final suggestions = _getTroubleshootingSuggestions(widget.error.type);

    return ExpansionTile(
      title: Text(
        'Troubleshooting Guide',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      leading: Icon(Icons.help_outline, color: AppTheme.primaryColor),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...suggestions
                  .map(_buildSuggestionItem),
              SizedBox(height: AppTheme.spacingM),
              _buildQuickActions(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionItem(String suggestion) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Text(
              suggestion,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = _getQuickActions(widget.error.type);

    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        SizedBox(height: AppTheme.spacingS),
        Wrap(
          spacing: AppTheme.spacingS,
          runSpacing: AppTheme.spacingS,
          children: actions.map(_buildActionChip).toList(),
        ),
      ],
    );
  }

  Widget _buildActionChip(QuickAction action) {
    return ActionChip(
      avatar: Icon(action.icon, size: 16),
      label: Text(action.label),
      onPressed: action.onPressed,
      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
      side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
    );
  }

  Widget _buildErrorDetails() {
    return ExpansionTile(
      title: Text(
        'Technical Details',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      leading: Icon(Icons.code, color: AppTheme.textColorLight),
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppTheme.spacingM),
          margin: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppTheme.textColorLight.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Error Type', widget.error.type.toString()),
              _buildDetailRow('Message', widget.error.message),
              _buildDetailRow('Timestamp', widget.error.timestamp.toString()),
              if (widget.error.requestId != null)
                _buildDetailRow('Request ID', widget.error.requestId!),
              if (widget.error.providerId != null)
                _buildDetailRow('Provider ID', widget.error.providerId!),
              if (widget.error.stackTrace != null) ...[
                SizedBox(height: AppTheme.spacingS),
                Text(
                  'Stack Trace:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.error.stackTrace.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                  ),
                ),
              ],
              SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyErrorDetails,
                      icon: Icon(Icons.copy, size: 16),
                      label: Text('Copy Details'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticsSection() {
    return ExpansionTile(
      title: Text(
        'System Diagnostics',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      leading: Icon(Icons.medical_services, color: AppTheme.warningColor),
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
          child: Column(
            children: [
              _buildDiagnosticItem(
                  'Network Connectivity', 'Checking...', Icons.network_check),
              _buildDiagnosticItem(
                  'Provider Availability', 'Checking...', Icons.computer),
              _buildDiagnosticItem(
                  'Authentication Status', 'Checking...', Icons.security),
              _buildDiagnosticItem(
                  'System Resources', 'Checking...', Icons.memory),
              SizedBox(height: AppTheme.spacingM),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _runDiagnostics,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Run Diagnostics'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticItem(String label, String status, IconData icon) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textColorLight),
          SizedBox(width: AppTheme.spacingS),
          Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        TextButton.icon(
          onPressed: () => setState(() => _showDetails = !_showDetails),
          icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
          label: Text(_showDetails ? 'Hide Details' : 'Show Details'),
        ),
        if (widget.showDiagnostics) ...[
          SizedBox(width: AppTheme.spacingS),
          TextButton.icon(
            onPressed: () =>
                setState(() => _showDiagnostics = !_showDiagnostics),
            icon: Icon(Icons.medical_services),
            label: Text('Diagnostics'),
          ),
        ],
        Spacer(),
        if (widget.onRetry != null) ...[
          ElevatedButton.icon(
            onPressed: widget.onRetry,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ],
    );
  }

  // Helper methods
  IconData _getErrorIcon(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
        return Icons.wifi_off;
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
        return Icons.access_time;
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return Icons.security;
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return Icons.search_off;
      case LLMCommunicationErrorType.modelNotFound:
      case LLMCommunicationErrorType.modelNotLoaded:
      case LLMCommunicationErrorType.modelError:
        return Icons.model_training;
      case LLMCommunicationErrorType.requestRateLimited:
        return Icons.speed;
      case LLMCommunicationErrorType.requestMalformed:
      case LLMCommunicationErrorType.responseParsingError:
        return Icons.error_outline;
      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.tunnelError:
        return Icons.dns;
      default:
        return Icons.error;
    }
  }

  Color _getErrorColor(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.tunnelError:
        return AppTheme.dangerColor;
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
      case LLMCommunicationErrorType.requestRateLimited:
        return AppTheme.warningColor;
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return Colors.orange;
      default:
        return AppTheme.dangerColor;
    }
  }

  String _getErrorTitle(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
        return 'Connection Failed';
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
        return 'Request Timeout';
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return 'Authentication Error';
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return 'Provider Not Found';
      case LLMCommunicationErrorType.modelNotFound:
      case LLMCommunicationErrorType.modelNotLoaded:
      case LLMCommunicationErrorType.modelError:
        return 'Model Not Available';
      case LLMCommunicationErrorType.requestRateLimited:
        return 'Rate Limited';
      case LLMCommunicationErrorType.requestMalformed:
      case LLMCommunicationErrorType.responseParsingError:
        return 'Invalid Request';
      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.tunnelError:
        return 'Server Error';
      default:
        return 'Unknown Error';
    }
  }

  String _getUserFriendlyMessage(LLMCommunicationError error) {
    switch (error.type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
        return 'Unable to connect to the LLM provider. Please check your network connection and ensure the provider is running.';
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
        return 'The request took too long to complete. The provider might be overloaded or experiencing issues.';
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return 'Authentication failed. Please check your credentials and ensure you have proper access.';
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return 'The specified LLM provider could not be found. It may not be configured or available.';
      case LLMCommunicationErrorType.modelNotFound:
      case LLMCommunicationErrorType.modelNotLoaded:
      case LLMCommunicationErrorType.modelError:
        return 'The requested model is not available on this provider. Please select a different model.';
      case LLMCommunicationErrorType.requestRateLimited:
        return 'Too many requests have been sent. Please wait a moment before trying again.';
      case LLMCommunicationErrorType.requestMalformed:
      case LLMCommunicationErrorType.responseParsingError:
        return 'The request format is invalid. This is likely a configuration issue.';
      case LLMCommunicationErrorType.systemError:
      case LLMCommunicationErrorType.tunnelError:
        return 'The provider encountered an internal error. Please try again later.';
      default:
        return error.message;
    }
  }

  List<String> _getTroubleshootingSuggestions(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
        return [
          'Verify that the LLM provider (Ollama, LM Studio, etc.) is running',
          'Check if the provider is accessible at the configured URL and port',
          'Ensure your firewall is not blocking the connection',
          'Try restarting the provider service',
        ];
      case LLMCommunicationErrorType.connectionTimeout:
      case LLMCommunicationErrorType.requestTimeout:
      case LLMCommunicationErrorType.responseTimeout:
        return [
          'Check if the provider is overloaded with requests',
          'Try using a smaller model or reducing the request complexity',
          'Increase the timeout setting in configuration',
          'Verify system resources (CPU, memory) are sufficient',
        ];
      case LLMCommunicationErrorType.authenticationFailed:
      case LLMCommunicationErrorType.authorizationDenied:
      case LLMCommunicationErrorType.tokenExpired:
        return [
          'Verify your API key or authentication credentials',
          'Check if your account has the necessary permissions',
          'Ensure the authentication method is correctly configured',
          'Try re-authenticating or refreshing your session',
        ];
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return [
          'Check the provider configuration settings',
          'Verify the provider URL and port are correct',
          'Ensure the provider is properly installed and running',
          'Try scanning for available providers',
        ];
      default:
        return [
          'Check the provider logs for more detailed error information',
          'Verify your configuration settings',
          'Try restarting the application',
          'Contact support if the issue persists',
        ];
    }
  }

  List<QuickAction> _getQuickActions(LLMCommunicationErrorType type) {
    switch (type) {
      case LLMCommunicationErrorType.connectionRefused:
      case LLMCommunicationErrorType.connectionLost:
      case LLMCommunicationErrorType.networkError:
        return [
          QuickAction('Test Connection', Icons.network_check, _testConnection),
          QuickAction('Scan Providers', Icons.search, _scanProviders),
        ];
      case LLMCommunicationErrorType.providerNotFound:
      case LLMCommunicationErrorType.providerUnavailable:
        return [
          QuickAction('Scan Providers', Icons.search, _scanProviders),
          QuickAction('Configure Provider', Icons.settings, _configureProvider),
        ];
      default:
        return [
          QuickAction('Check Status', Icons.info, _checkStatus),
        ];
    }
  }

  void _copyErrorDetails() {
    final details = '''
Error Type: ${widget.error.type}
Message: ${widget.error.message}
Timestamp: ${widget.error.timestamp}
${widget.error.requestId != null ? 'Request ID: ${widget.error.requestId}\n' : ''}
${widget.error.providerId != null ? 'Provider ID: ${widget.error.providerId}\n' : ''}
${widget.error.context?.isNotEmpty == true ? 'Context: ${widget.error.context}\n' : ''}
${widget.error.stackTrace != null ? 'Stack Trace:\n${widget.error.stackTrace}\n' : ''}
''';

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error details copied to clipboard')),
    );
  }

  void _runDiagnostics() {
    _showDiagnosticsDialog();
  }

  /// Show comprehensive diagnostics dialog
  void _showDiagnosticsDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiagnosticsDialog(),
    );
  }

  void _testConnection() {
    _showConnectionTestDialog();
  }

  /// Show connection test dialog
  void _showConnectionTestDialog() {
    showDialog(
      context: context,
      builder: (context) => _ConnectionTestDialog(),
    );
  }

  void _scanProviders() async {
    try {
      final discoveryService =
          Provider.of<ProviderDiscoveryService>(context, listen: false);

      // Show loading snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Scanning for providers...'),
          backgroundColor: Colors.blue,
        ),
      );

      // Trigger provider scan
      await discoveryService.scanForProviders();

      // Show results
      final providers = discoveryService.discoveredProviders;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${providers.length} providers'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Provider scan failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _configureProvider() {
    try {
      // Navigate to unified settings screen (provider configuration section)
      Navigator.of(context).pushNamed('/settings');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open provider configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkStatus() {
    _showSystemStatusDialog();
  }

  /// Show system status dialog
  void _showSystemStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => _SystemStatusDialog(),
    );
  }
}

/// Quick action definition
class QuickAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const QuickAction(this.label, this.icon, this.onPressed);
}

/// Diagnostics dialog widget
class _DiagnosticsDialog extends StatefulWidget {
  @override
  State<_DiagnosticsDialog> createState() => _DiagnosticsDialogState();
}

class _DiagnosticsDialogState extends State<_DiagnosticsDialog> {
  bool _isRunning = false;
  final List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    try {
      // Check connection manager
      final connectionManager =
          Provider.of<ConnectionManagerService>(context, listen: false);
      _results.add(
          '✓ Connection Manager: ${connectionManager.hasAnyConnection ? 'Connected' : 'Disconnected'}');

      // Check provider manager
      final providerManager =
          Provider.of<LLMProviderManager>(context, listen: false);
      _results.add(
          '✓ Provider Manager: ${providerManager.isInitialized ? 'Initialized' : 'Not initialized'}');
      _results.add(
          '✓ Available Providers: ${providerManager.availableProviders.length}');

      // Check discovery service
      final discoveryService =
          Provider.of<ProviderDiscoveryService>(context, listen: false);
      _results.add(
          '✓ Discovery Service: ${discoveryService.discoveredProviders.length} providers found');

      _results.add('✓ Diagnostics completed successfully');
    } catch (e) {
      _results.add('✗ Diagnostic error: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('System Diagnostics'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            if (_isRunning) ...[
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Running diagnostics...'),
            ] else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_results[index]),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!_isRunning)
          TextButton(
            onPressed: _runDiagnostics,
            child: const Text('Run Again'),
          ),
      ],
    );
  }
}

/// Connection test dialog widget
class _ConnectionTestDialog extends StatefulWidget {
  @override
  State<_ConnectionTestDialog> createState() => _ConnectionTestDialogState();
}

class _ConnectionTestDialogState extends State<_ConnectionTestDialog> {
  bool _isRunning = false;
  final List<String> _results = [];

  @override
  void initState() {
    super.initState();
    _runConnectionTests();
  }

  Future<void> _runConnectionTests() async {
    setState(() {
      _isRunning = true;
      _results.clear();
    });

    try {
      // Test connection manager
      final connectionManager =
          Provider.of<ConnectionManagerService>(context, listen: false);
      _results.add('Testing connection manager...');

      if (connectionManager.hasLocalConnection) {
        _results.add('✓ Local Ollama: Connected');
      } else {
        _results.add('✗ Local Ollama: Disconnected');
      }

      if (connectionManager.hasCloudConnection) {
        _results.add('✓ Cloud Tunnel: Connected');
      } else {
        _results.add('✗ Cloud Tunnel: Disconnected');
      }

      // Test providers
      final providerManager =
          Provider.of<LLMProviderManager>(context, listen: false);
      _results.add('Testing providers...');

      for (final provider in providerManager.availableProviders) {
        final isHealthy =
            await providerManager.testProviderConnection(provider.info.id);
        _results.add(
            '${isHealthy ? '✓' : '✗'} ${provider.info.name}: ${isHealthy ? 'Connected' : 'Failed'}');
      }

      _results.add('Connection tests completed');
    } catch (e) {
      _results.add('✗ Connection test error: $e');
    }

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Connection Test'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            if (_isRunning) ...[
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Testing connections...'),
            ] else ...[
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(_results[index]),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!_isRunning)
          TextButton(
            onPressed: _runConnectionTests,
            child: const Text('Test Again'),
          ),
      ],
    );
  }
}

/// System status dialog widget
class _SystemStatusDialog extends StatefulWidget {
  @override
  State<_SystemStatusDialog> createState() => _SystemStatusDialogState();
}

class _SystemStatusDialogState extends State<_SystemStatusDialog> {
  Map<String, dynamic> _statusData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSystemStatus();
  }

  Future<void> _loadSystemStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final connectionManager =
          Provider.of<ConnectionManagerService>(context, listen: false);
      final providerManager =
          Provider.of<LLMProviderManager>(context, listen: false);

      _statusData = {
        'Connection Status': {
          'Local Connection': connectionManager.hasLocalConnection
              ? 'Connected'
              : 'Disconnected',
          'Cloud Connection': connectionManager.hasCloudConnection
              ? 'Connected'
              : 'Disconnected',
        },
        'Provider Status': {
          'Total Providers':
              providerManager.registeredProviders.length.toString(),
          'Available Providers':
              providerManager.availableProviders.length.toString(),
          'Healthy Providers':
              providerManager.healthyProviders.length.toString(),
        },
        'System Info': {
          'Provider Manager':
              providerManager.isInitialized ? 'Initialized' : 'Not Initialized',
          'Connection Type':
              connectionManager.getBestConnectionType().toString(),
        },
      };
    } catch (e) {
      _statusData = {
        'Error': {'Status': 'Failed to load system status: $e'}
      };
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('System Status'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Loading system status...'),
                  ],
                ),
              )
            : ListView(
                children: _statusData.entries.map((category) {
                  return ExpansionTile(
                    title: Text(category.key),
                    children: (category.value as Map<String, dynamic>)
                        .entries
                        .map((item) => ListTile(
                              title: Text(item.key),
                              trailing: Text(item.value.toString()),
                            ))
                        .toList(),
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        TextButton(
          onPressed: _loadSystemStatus,
          child: const Text('Refresh'),
        ),
      ],
    );
  }
}
