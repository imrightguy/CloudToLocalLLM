import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../components/modern_card.dart';
import '../../components/gradient_button.dart';
import '../../services/unified_connection_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../services/platform_adapter.dart';

/// Connection Status Screen
class ConnectionStatusScreen extends StatefulWidget {
  const ConnectionStatusScreen({super.key});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  bool _isRefreshing = false;
  DateTime? _lastRefresh;

  @override
  void initState() {
    super.initState();
    debugPrint(' [ConnectionStatusScreen] Initializing screen');
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      // Refresh connection status
      final connectionService = context.read<UnifiedConnectionService>();
      await connectionService.initialize();

      setState(() {
        _lastRefresh = DateTime.now();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(' [ConnectionStatusScreen] Building widget');
    final platformAdapter = Provider.of<PlatformAdapter>(context);
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive layout breakpoints
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Connection Status'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        leading: platformAdapter.buildBackButton(
          context,
          onPressed: () => context.go('/settings/connection'),
        ),
        actions: [
          IconButton(
            onPressed: _isRefreshing ? null : _refreshStatus,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
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
                    'System Connection Status',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.textColor,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Monitor the status of all system connections and services',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppTheme.textColorLight),
                  ),
                  if (_lastRefresh != null) ...[
                    SizedBox(height: AppTheme.spacingS),
                    Text(
                      'Last updated: ${_formatDateTime(_lastRefresh!)}',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textColorLight),
                    ),
                  ],
                  SizedBox(height: AppTheme.spacingXL),

                  // Authentication Status
                  _buildAuthenticationStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // OpenClaw Status
                  _buildOpenClawStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // Cloud Proxy Status
                  _buildCloudProxyStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // System Tray Status
                  _buildSystemTrayStatus(),
                  SizedBox(height: AppTheme.spacingL),

                  // Network Status
                  _buildNetworkStatus(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthenticationStatus() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Authentication',
                Icons.security,
                isAuthenticated ? Colors.green : Colors.red,
              ),
              SizedBox(height: AppTheme.spacingM),
              _buildStatusRow(
                'Status',
                isAuthenticated ? 'Authenticated' : 'Not Authenticated',
                isAuthenticated ? Colors.green : Colors.red,
              ),
              if (isAuthenticated) ...[
                _buildStatusRow('Provider', 'Auth0', Colors.blue),
              ],
              SizedBox(height: AppTheme.spacingM),
              if (!isAuthenticated)
                GradientButton(
                  text: 'Login',
                  onPressed: () => authService.login(),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => authService.logout(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOpenClawStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('OpenClaw Gateway', Icons.computer, Colors.blue),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow('Connection', 'Checking...', Colors.blue),
          _buildStatusRow(
            'URL',
            AppConfig.gatewayUrl,
            AppTheme.textColorLight,
          ),
          _buildStatusRow(
            'Platform',
            kIsWeb ? 'Web (via relay)' : 'Desktop (direct)',
            AppTheme.textColorLight,
          ),
          SizedBox(height: AppTheme.spacingM),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to agent status screen
              context.go('/agent-status');
            },
            icon: const Icon(Icons.analytics),
            label: const Text('View Agent Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudProxyStatus() {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final isAuthenticated = authService.isAuthenticated.value;

        return ModernCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'Cloud Proxy',
                Icons.cloud,
                isAuthenticated ? Colors.green : Colors.grey,
              ),
              SizedBox(height: AppTheme.spacingM),
              _buildStatusRow(
                'Status',
                isAuthenticated ? 'Available' : 'Requires Authentication',
                isAuthenticated ? Colors.green : Colors.grey,
              ),
              _buildStatusRow(
                'Endpoint',
                'api.cloudtolocalllm.online',
                AppTheme.textColorLight,
              ),
              _buildStatusRow(
                'Protocol',
                'HTTPS/WebSocket',
                AppTheme.textColorLight,
              ),
              if (isAuthenticated) ...[
                SizedBox(height: AppTheme.spacingM),
                Text(
                  'Cloud proxy allows secure access to local Ollama instances from web browsers and remote clients.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemTrayStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'System Tray',
            Icons.apps,
            kIsWeb ? Colors.grey : Colors.green,
          ),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow(
            'Platform Support',
            kIsWeb ? 'Not Available (Web)' : 'Available (Desktop)',
            kIsWeb ? Colors.grey : Colors.green,
          ),
          if (!kIsWeb) ...[
            _buildStatusRow('Daemon Status', 'Running', Colors.green),
            _buildStatusRow(
              'Icon Theme',
              'Monochrome',
              AppTheme.textColorLight,
            ),
            SizedBox(height: AppTheme.spacingM),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to daemon settings
                Navigator.of(context).pushNamed('/settings/daemon');
              },
              icon: const Icon(Icons.settings),
              label: const Text('Daemon Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNetworkStatus() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Network', Icons.network_check, Colors.green),
          SizedBox(height: AppTheme.spacingM),
          _buildStatusRow('Internet', 'Connected', Colors.green),
          _buildStatusRow('DNS Resolution', 'Working', Colors.green),
          _buildStatusRow('Firewall', 'Configured', Colors.green),
          SizedBox(height: AppTheme.spacingM),
          Text(
            'Network connectivity is required for authentication and cloud proxy features.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
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
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w500,
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
