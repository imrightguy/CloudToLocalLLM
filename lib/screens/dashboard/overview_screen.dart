import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../di/locator.dart' as di;
import '../../services/connection_manager_service.dart';
import '../../services/voice/voice_conversation_service.dart';
import '../../widgets/navigation/breadcrumb_bar.dart';
import '../../widgets/voice/open_voice_ui_control_panel.dart';
import '../../widgets/voice/voice_conversation_status_card.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final connService = context.read<ConnectionManagerService>();
    await connService.testConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gateway status, entry points, and a fast health read.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<ConnectionManagerService>(
                    builder: (context, connService, child) {
                      final gatewayStatus = connService.getGatewayStatus();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            'Voice Companion',
                            'Natural conversation state, backend switching, and agent control for the CloudToLocalLLM voice shell layered around Hermes.',
                            di.serviceLocator
                                    .isRegistered<VoiceConversationService>()
                                ? Column(
                                    children: [
                                      const VoiceConversationStatusCard(),
                                      const SizedBox(height: 16),
                                      const OpenVoiceUIControlPanel(),
                                    ],
                                  )
                                : _buildVoiceUnavailableCard(),
                          ),

                          const SizedBox(height: 24),

                          // Gateway Access Section
                          _buildSection(
                            'Gateway Access',
                            'Where the dashboard connects and how it authenticates.',
                            _buildGatewayAccessCard(connService),
                          ),

                          const SizedBox(height: 24),

                          // Snapshot Section
                          _buildSection(
                            'Snapshot',
                            'Latest gateway handshake information.',
                            _buildSnapshotCard(gatewayStatus),
                          ),

                          const SizedBox(height: 24),

                          // Quick Stats
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Instances',
                                  gatewayStatus['instances']?.toString() ?? '0',
                                  'Presence beacons in the last 5 minutes',
                                  Icons.devices,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildStatCard(
                                  'Sessions',
                                  gatewayStatus['sessions']?.toString() ??
                                      'n/a',
                                  'Recent session keys tracked by the gateway',
                                  Icons.history,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String description, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildGatewayAccessCard(ConnectionManagerService connService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormField(
              'WebSocket URL',
              connService.getGatewayStatus()['endpoint'] ??
                  'ws://127.0.0.1:18789',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Gateway Token',
              connService.gatewayToken != null &&
                      connService.gatewayToken!.length >= 16
                  ? '${connService.gatewayToken!.substring(0, 16)}...'
                  : 'Not set',
            ),
            const SizedBox(height: 16),
            _buildFormField(
              'Default Session Key',
              'main',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Connect'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCard(Map<String, dynamic> gatewayStatus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSnapshotRow('Status',
                gatewayStatus['healthStatus']?.toString() ?? 'Unknown'),
            _buildSnapshotRow('Uptime', gatewayStatus['uptime'] ?? 'n/a'),
            _buildSnapshotRow(
                'Last Channels Refresh', gatewayStatus['lastRefresh'] ?? 'n/a'),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceUnavailableCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Voice conversation service is only wired on desktop builds right now.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
      ),
    );
  }

  Widget _buildFormField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildSnapshotRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
