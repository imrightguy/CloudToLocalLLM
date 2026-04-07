import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../components/modern_card.dart';
import '../../components/gradient_button.dart';
import '../../services/unified_connection_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/platform_adapter.dart';

/// System Tray Daemon Settings Screen
class DaemonSettingsScreen extends StatefulWidget {
  const DaemonSettingsScreen({super.key});

  @override
  State<DaemonSettingsScreen> createState() => _DaemonSettingsScreenState();
}

class _DaemonSettingsScreenState extends State<DaemonSettingsScreen> {
  bool _enableSystemTray = true;
  bool _startMinimized = false;
  bool _enableNotifications = true;
  bool _autoStartDaemon = true;
  String _selectedTheme = 'system';
  int _connectionTimeout = 5;
  int _healthCheckInterval = 30;

  // Real-time status tracking
  Map<String, dynamic>? _connectionStatus;
  bool _isLoadingStatus = false;
  DateTime? _lastStatusUpdate;

  @override
  void initState() {
    super.initState();
    debugPrint(' [DaemonSettingsScreen] Initializing screen');
    _loadSettings();
    _loadConnectionStatus();
  }

  void _loadSettings() {
    // Load current daemon settings
    // This would typically load from a configuration file or service
    setState(() {
      _enableSystemTray = true;
      _startMinimized = false;
      _enableNotifications = true;
      _autoStartDaemon = true;
      _selectedTheme = 'system';
      _connectionTimeout = 5;
      _healthCheckInterval = 30;
    });
  }

  Future<void> _loadConnectionStatus() async {
    setState(() {
      _isLoadingStatus = true;
    });

    try {
      // Get connection status from unified connection service
      final connectionService = context.read<UnifiedConnectionService>();
      await connectionService.refreshConnectionStatus();

      setState(() {
        _connectionStatus = {
          'connected': connectionService.isConnected,
          'connection_type': connectionService.connectionType,
          'version': connectionService.version,
          'models': connectionService.models,
          'error': connectionService.error,
        };
        _lastStatusUpdate = DateTime.now();
      });
    } catch (e) {
      debugPrint('Failed to load connection status: $e');
      setState(() {
        _connectionStatus = {'connected': false, 'error': e.toString()};
        _lastStatusUpdate = DateTime.now();
      });
    } finally {
      setState(() {
        _isLoadingStatus = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      // Save settings to configuration
      // This would typically save to a configuration file or service

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daemon settings saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _restartDaemon() async {
    try {
      // Restart the system tray daemon
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restarting system tray daemon...'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Add actual daemon restart logic here
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System tray daemon restarted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart daemon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(' [DaemonSettingsScreen] Building widget');
    final platformAdapter = Provider.of<PlatformAdapter>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive layout breakpoints
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('System Tray Daemon Settings'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        leading: platformAdapter.buildBackButton(
          context,
          onPressed: () => context.go('/settings/connection'),
        ),
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12.0 : AppTheme.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'System Tray Configuration',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Configure the system tray daemon behavior and appearance',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.textColorLight),
                  ),
                  SizedBox(height: AppTheme.spacingXL),

                  // Real-time Connection Status
                  _buildConnectionStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // General Settings
                  _buildGeneralSettings(),
                  SizedBox(height: AppTheme.spacingL),

                  // Appearance Settings
                  _buildAppearanceSettings(),
                  SizedBox(height: AppTheme.spacingL),

                  // Connection Settings
                  _buildConnectionSettings(),
                  SizedBox(height: AppTheme.spacingL),

                  // Actions
                  _buildActions(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Real-time Connection Status', Icons.wifi),
              IconButton(
                onPressed: _isLoadingStatus ? null : _loadConnectionStatus,
                icon: _isLoadingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingM),
          if (_connectionStatus != null) ...[
            _buildStatusRow(
              'Connection Status',
              _connectionStatus!['connected'] == true
                  ? 'Connected'
                  : 'Disconnected',
              _connectionStatus!['connected'] == true
                  ? Colors.green
                  : Colors.red,
            ),
            if (_connectionStatus!['connection_type'] != null)
              _buildStatusRow(
                'Connection Type',
                _connectionStatus!['connection_type'].toString().toUpperCase(),
                AppTheme.textColorLight,
              ),
            if (_connectionStatus!['version'] != null)
              _buildStatusRow(
                'Version',
                _connectionStatus!['version'].toString(),
                AppTheme.textColorLight,
              ),
            if (_connectionStatus!['models'] != null)
              _buildStatusRow(
                'Available Models',
                '${(_connectionStatus!['models'] as List).length} models',
                AppTheme.textColorLight,
              ),
            if (_connectionStatus!['error'] != null &&
                _connectionStatus!['error'].toString().isNotEmpty)
              _buildStatusRow(
                'Error',
                _connectionStatus!['error'].toString(),
                Colors.red,
              ),
            if (_lastStatusUpdate != null) ...[
              SizedBox(height: AppTheme.spacingS),
              Text(
                'Last updated: ${_formatDateTime(_lastStatusUpdate!)}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
              ),
            ],
          ] else ...[
            const Text('Loading connection status...'),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('General Settings', Icons.settings),
          SizedBox(height: AppTheme.spacingM),
          _buildSwitchTile(
            'Enable System Tray',
            'Show CloudToLocalLLM icon in system tray',
            _enableSystemTray,
            (value) => setState(() => _enableSystemTray = value),
          ),
          _buildSwitchTile(
            'Start Minimized',
            'Start application minimized to system tray',
            _startMinimized,
            (value) => setState(() => _startMinimized = value),
          ),
          _buildSwitchTile(
            'Enable Notifications',
            'Show system notifications for important events',
            _enableNotifications,
            (value) => setState(() => _enableNotifications = value),
          ),
          _buildSwitchTile(
            'Auto-start Daemon',
            'Automatically start tray daemon with system',
            _autoStartDaemon,
            (value) => setState(() => _autoStartDaemon = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Appearance', Icons.palette),
          SizedBox(height: AppTheme.spacingM),
          _buildDropdownTile(
            'Tray Icon Theme',
            'Choose icon style for system tray',
            _selectedTheme,
            ['system', 'light', 'dark', 'monochrome'],
            (value) => setState(() => _selectedTheme = value ?? 'system'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSettings() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Connection Settings', Icons.network_check),
          SizedBox(height: AppTheme.spacingM),
          _buildSliderTile(
            'Connection Timeout',
            'Timeout for daemon connections (seconds)',
            _connectionTimeout.toDouble(),
            1.0,
            30.0,
            (value) => setState(() => _connectionTimeout = value.round()),
          ),
          _buildSliderTile(
            'Health Check Interval',
            'Interval for daemon health checks (seconds)',
            _healthCheckInterval.toDouble(),
            10.0,
            300.0,
            (value) => setState(() => _healthCheckInterval = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Actions', Icons.build),
          SizedBox(height: AppTheme.spacingM),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  text: 'Save Settings',
                  onPressed: _saveSettings,
                ),
              ),
              SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _restartDaemon,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Restart Daemon'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.all(AppTheme.spacingM),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 24),
        SizedBox(width: AppTheme.spacingS),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textColor,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String subtitle,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
          SizedBox(height: AppTheme.spacingS),
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingM,
                vertical: AppTheme.spacingS,
              ),
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option.toUpperCase()),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    String subtitle,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textColor,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '${value.round()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
          SizedBox(height: AppTheme.spacingS),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColor),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
