import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/agent_status_service.dart';
import '../../components/agent_status_widget.dart';
import '../../components/app_logo.dart';
import 'package:get_it/get_it.dart';

/// Screen for monitoring OpenClaw agent status in real-time
class AgentStatusScreen extends StatefulWidget {
  const AgentStatusScreen({super.key});

  @override
  State<AgentStatusScreen> createState() => _AgentStatusScreenState();
}

class _AgentStatusScreenState extends State<AgentStatusScreen> {
  AgentStatusService? _statusService;

  @override
  void initState() {
    super.initState();
    // Use singleton from service locator if available
    try {
      _statusService = GetIt.instance.get<AgentStatusService>();
      _statusService!.startPolling();
    } catch (e) {
      debugPrint('[AgentStatusScreen] AgentStatusService not available: $e');
    }
  }

  @override
  void dispose() {
    // Don't dispose the singleton - just stop polling
    _statusService?.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
          tooltip: 'Back to Chat',
        ),
        title: Row(
          children: [
            const AppLogo.small(),
            const SizedBox(width: 12),
            const Text('Agent Status'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: AgentStatusWidget(
                service: _statusService,
                showDetails: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              '🦞',
              style: TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CloudToLocalLLM Agent Monitor',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Real-time monitoring of OpenClaw agent sessions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
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
}
