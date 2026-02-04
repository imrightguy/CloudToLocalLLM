/// Enhanced Provider Status Widget for Zoidbot
///
/// This widget provides comprehensive provider status information including:
/// - Real-time health monitoring
/// - Performance metrics display
/// - Provider-specific configuration details
/// - Interactive provider management
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/llm_provider_manager.dart';
import '../services/provider_configuration_manager.dart';
import '../services/provider_discovery_service.dart';

/// Enhanced provider status widget with detailed health information
class EnhancedProviderStatusWidget extends StatefulWidget {
  final String? providerId;
  final bool showMetrics;
  final bool showConfiguration;
  final bool allowProviderSwitch;
  final VoidCallback? onProviderTap;

  const EnhancedProviderStatusWidget({
    super.key,
    this.providerId,
    this.showMetrics = true,
    this.showConfiguration = false,
    this.allowProviderSwitch = true,
    this.onProviderTap,
  });

  @override
  State<EnhancedProviderStatusWidget> createState() =>
      _EnhancedProviderStatusWidgetState();
}

class _EnhancedProviderStatusWidgetState
    extends State<EnhancedProviderStatusWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<LLMProviderManager, ProviderConfigurationManager>(
      builder: (context, providerManager, configManager, child) {
        final provider = widget.providerId != null
            ? providerManager.getProvider(widget.providerId!)
            : providerManager.getPreferredProvider();

        if (provider == null) {
          return _buildNoProviderCard();
        }

        return Card(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
          child: InkWell(
            onTap: widget.onProviderTap ??
                () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProviderHeader(provider),
                  if (_isExpanded) ...[
                    SizedBox(height: AppTheme.spacingM),
                    _buildProviderDetails(provider, configManager),
                    if (widget.showMetrics) ...[
                      SizedBox(height: AppTheme.spacingM),
                      _buildMetricsSection(provider),
                    ],
                    if (widget.showConfiguration) ...[
                      SizedBox(height: AppTheme.spacingM),
                      _buildConfigurationSection(provider, configManager),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoProviderCard() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingM),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: AppTheme.warningColor, size: 24),
            SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No Provider Available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.warningColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: AppTheme.spacingXS),
                  Text(
                    'No LLM providers are currently configured or available.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderHeader(RegisteredProvider provider) {
    final healthStatus = provider.healthStatus;
    final statusColor = _getHealthStatusColor(healthStatus);
    final statusIcon = _getHealthStatusIcon(healthStatus);
    final isActive = provider.isEnabled;

    return Row(
      children: [
        // Provider type icon
        Container(
          padding: EdgeInsets.all(AppTheme.spacingS),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getProviderTypeIcon(provider.info.type),
            color: statusColor,
            size: 24,
          ),
        ),
        SizedBox(width: AppTheme.spacingM),

        // Provider info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    provider.info.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (isActive) ...[
                    SizedBox(width: AppTheme.spacingS),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingS,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(height: AppTheme.spacingXS),
              Row(
                children: [
                  Icon(statusIcon, size: 16, color: statusColor),
                  SizedBox(width: AppTheme.spacingXS),
                  Text(
                    _getHealthStatusText(healthStatus),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  SizedBox(width: AppTheme.spacingM),
                  Text(
                    provider.info.baseUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textColorLight,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Expand/collapse indicator
        Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: AppTheme.textColorLight,
        ),
      ],
    );
  }

  Widget _buildProviderDetails(
      RegisteredProvider provider, ProviderConfigurationManager configManager) {
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
            'Provider Details',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildDetailRow(
              'Type', provider.info.type.toString().split('.').last),
          _buildDetailRow('Port', provider.info.port.toString()),
          _buildDetailRow('Version', provider.info.version ?? 'Unknown'),
          _buildDetailRow(
              'Models', '${provider.info.availableModels.length} available'),
          _buildDetailRow('Last Seen', _formatLastSeen(provider.info.lastSeen)),
          if (provider.info.capabilities.isNotEmpty) ...[
            SizedBox(height: AppTheme.spacingS),
            Text(
              'Capabilities',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: AppTheme.spacingXS),
            Wrap(
              spacing: AppTheme.spacingXS,
              runSpacing: AppTheme.spacingXS,
              children: provider.info.capabilities.entries
                  .where((entry) => entry.value == true)
                  .map((entry) => _buildCapabilityChip(entry.key))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsSection(RegisteredProvider provider) {
    final metrics = provider.metrics;

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
            'Performance Metrics',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Success Rate',
                  '${(metrics.successRate * 100).toStringAsFixed(1)}%',
                  Icons.check_circle_outline,
                  _getSuccessRateColor(metrics.successRate),
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildMetricCard(
                  'Avg Response',
                  '${metrics.averageResponseTime.toStringAsFixed(0)}ms',
                  Icons.speed,
                  _getResponseTimeColor(metrics.averageResponseTime),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Total Requests',
                  metrics.totalRequests.toString(),
                  Icons.analytics_outlined,
                  AppTheme.primaryColor,
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: _buildMetricCard(
                  'Failed Requests',
                  metrics.failedRequests.toString(),
                  Icons.error_outline,
                  metrics.failedRequests > 0
                      ? AppTheme.dangerColor
                      : AppTheme.successColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationSection(
      RegisteredProvider provider, ProviderConfigurationManager configManager) {
    final config = configManager.getConfiguration(provider.info.id);

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configuration',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              TextButton.icon(
                onPressed: () => _editConfiguration(provider.info.id),
                icon: Icon(Icons.edit, size: 16),
                label: Text('Edit'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          if (config != null) ...[
            _buildDetailRow('Timeout', '${config.timeout.inSeconds}s'),
            _buildDetailRow('Provider ID', config.providerId),
            if (config.customSettings.isNotEmpty)
              _buildDetailRow('Custom Settings',
                  '${config.customSettings.length} configured'),
          ] else ...[
            Text(
              'No custom configuration found. Using default settings.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
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
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                    fontWeight: FontWeight.w500,
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

  Widget _buildCapabilityChip(String capability) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        capability,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: AppTheme.spacingS),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getHealthStatusColor(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return AppTheme.successColor;
      case ProviderHealthStatus.degraded:
        return AppTheme.warningColor;
      case ProviderHealthStatus.unhealthy:
        return AppTheme.dangerColor;
      case ProviderHealthStatus.unknown:
        return AppTheme.textColorLight;
    }
  }

  IconData _getHealthStatusIcon(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return Icons.check_circle;
      case ProviderHealthStatus.degraded:
        return Icons.warning;
      case ProviderHealthStatus.unhealthy:
        return Icons.error;
      case ProviderHealthStatus.unknown:
        return Icons.help_outline;
    }
  }

  String _getHealthStatusText(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return 'Healthy';
      case ProviderHealthStatus.degraded:
        return 'Degraded';
      case ProviderHealthStatus.unhealthy:
        return 'Unhealthy';
      case ProviderHealthStatus.unknown:
        return 'Unknown';
    }
  }

  IconData _getProviderTypeIcon(ProviderType type) {
    switch (type) {
      case ProviderType.ollama:
        return Icons.computer;
      case ProviderType.lmStudio:
        return Icons.desktop_windows;
      case ProviderType.openAICompatible:
        return Icons.cloud;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getSuccessRateColor(double successRate) {
    if (successRate >= 0.95) return AppTheme.successColor;
    if (successRate >= 0.8) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  Color _getResponseTimeColor(double responseTime) {
    if (responseTime < 1000) return AppTheme.successColor;
    if (responseTime < 5000) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  void _editConfiguration(String providerId) {
    try {
      // Navigate to unified settings screen with provider configuration focus
      Navigator.of(context).pushNamed(
        '/settings',
        arguments: {
          'section': 'providers',
          'providerId': providerId,
        },
      );
    } catch (e) {
      // Fallback: show snackbar with error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open provider configuration: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

/// Provider selection interface with enhanced features
class EnhancedProviderSelectorWidget extends StatefulWidget {
  final String? selectedProviderId;
  final ValueChanged<String?>? onProviderSelected;
  final bool showHealthIndicators;
  final bool showMetrics;
  final bool allowMultipleSelection;

  const EnhancedProviderSelectorWidget({
    super.key,
    this.selectedProviderId,
    this.onProviderSelected,
    this.showHealthIndicators = true,
    this.showMetrics = false,
    this.allowMultipleSelection = false,
  });

  @override
  State<EnhancedProviderSelectorWidget> createState() =>
      _EnhancedProviderSelectorWidgetState();
}

class _EnhancedProviderSelectorWidgetState
    extends State<EnhancedProviderSelectorWidget> {
  String? _selectedProviderId;
  final Set<String> _selectedProviderIds = {};

  @override
  void initState() {
    super.initState();
    _selectedProviderId = widget.selectedProviderId;
    if (_selectedProviderId != null) {
      _selectedProviderIds.add(_selectedProviderId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LLMProviderManager>(
      builder: (context, providerManager, child) {
        final providers = providerManager.registeredProviders;

        if (providers.isEmpty) {
          return _buildNoProvidersCard();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Providers',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: AppTheme.spacingM),
            ...providers
                .map(_buildProviderSelectionCard),
            if (widget.allowMultipleSelection &&
                _selectedProviderIds.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacingM),
              _buildSelectionSummary(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildNoProvidersCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppTheme.textColorLight,
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No Providers Found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
            ),
            SizedBox(height: AppTheme.spacingS),
            Text(
              'No LLM providers are currently available. Please check your configuration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelectionCard(RegisteredProvider provider) {
    final isSelected = widget.allowMultipleSelection
        ? _selectedProviderIds.contains(provider.info.id)
        : _selectedProviderId == provider.info.id;

    final healthColor = _getHealthStatusColor(provider.healthStatus);

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: InkWell(
        onTap: () => _selectProvider(provider.info.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: AppTheme.primaryColor, width: 2)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                // Selection indicator
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textColorLight,
                      width: 2,
                    ),
                    color:
                        isSelected ? AppTheme.primaryColor : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                SizedBox(width: AppTheme.spacingM),

                // Provider icon
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingS),
                  decoration: BoxDecoration(
                    color: healthColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getProviderTypeIcon(provider.info.type),
                    color: healthColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: AppTheme.spacingM),

                // Provider info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.info.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      SizedBox(height: AppTheme.spacingXS),
                      Row(
                        children: [
                          if (widget.showHealthIndicators) ...[
                            Icon(
                              _getHealthStatusIcon(provider.healthStatus),
                              size: 14,
                              color: healthColor,
                            ),
                            SizedBox(width: AppTheme.spacingXS),
                            Text(
                              _getHealthStatusText(provider.healthStatus),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: healthColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            SizedBox(width: AppTheme.spacingM),
                          ],
                          Text(
                            provider.info.baseUrl,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.textColorLight,
                                    ),
                          ),
                        ],
                      ),
                      if (widget.showMetrics &&
                          provider.metrics.totalRequests > 0) ...[
                        SizedBox(height: AppTheme.spacingXS),
                        Text(
                          'Success: ${(provider.metrics.successRate * 100).toStringAsFixed(1)}% • '
                          'Avg: ${provider.metrics.averageResponseTime.toStringAsFixed(0)}ms',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.textColorLight,
                                  ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Active indicator
                if (provider.isEnabled)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'AVAILABLE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSummary() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
          SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Text(
              '${_selectedProviderIds.length} provider${_selectedProviderIds.length == 1 ? '' : 's'} selected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          TextButton(
            onPressed: _clearSelection,
            child: Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _selectProvider(String providerId) {
    setState(() {
      if (widget.allowMultipleSelection) {
        if (_selectedProviderIds.contains(providerId)) {
          _selectedProviderIds.remove(providerId);
        } else {
          _selectedProviderIds.add(providerId);
        }
      } else {
        _selectedProviderId =
            _selectedProviderId == providerId ? null : providerId;
      }
    });

    if (widget.onProviderSelected != null) {
      if (widget.allowMultipleSelection) {
        // For multiple selection, we could pass the first selected or handle differently
        widget.onProviderSelected!(_selectedProviderIds.isNotEmpty
            ? _selectedProviderIds.first
            : null);
      } else {
        widget.onProviderSelected!(_selectedProviderId);
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedProviderIds.clear();
      _selectedProviderId = null;
    });

    if (widget.onProviderSelected != null) {
      widget.onProviderSelected!(null);
    }
  }

  // Helper methods (reused from EnhancedProviderStatusWidget)
  Color _getHealthStatusColor(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return AppTheme.successColor;
      case ProviderHealthStatus.degraded:
        return AppTheme.warningColor;
      case ProviderHealthStatus.unhealthy:
        return AppTheme.dangerColor;
      case ProviderHealthStatus.unknown:
        return AppTheme.textColorLight;
    }
  }

  IconData _getHealthStatusIcon(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return Icons.check_circle;
      case ProviderHealthStatus.degraded:
        return Icons.warning;
      case ProviderHealthStatus.unhealthy:
        return Icons.error;
      case ProviderHealthStatus.unknown:
        return Icons.help_outline;
    }
  }

  String _getHealthStatusText(ProviderHealthStatus status) {
    switch (status) {
      case ProviderHealthStatus.healthy:
        return 'Healthy';
      case ProviderHealthStatus.degraded:
        return 'Degraded';
      case ProviderHealthStatus.unhealthy:
        return 'Unhealthy';
      case ProviderHealthStatus.unknown:
        return 'Unknown';
    }
  }

  IconData _getProviderTypeIcon(ProviderType type) {
    switch (type) {
      case ProviderType.ollama:
        return Icons.computer;
      case ProviderType.lmStudio:
        return Icons.desktop_windows;
      case ProviderType.openAICompatible:
        return Icons.cloud;
      default:
        return Icons.device_unknown;
    }
  }
}
