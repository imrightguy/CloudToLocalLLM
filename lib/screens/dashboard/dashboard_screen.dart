import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cloudtolocalllm/screens/dashboard/agent_list_view.dart';
import 'package:cloudtolocalllm/screens/dashboard/agent_detail_screen.dart';
import 'package:cloudtolocalllm/screens/dashboard/event_stream_screen.dart';
import 'package:cloudtolocalllm/screens/dashboard/resource_overview_screen.dart';
import 'package:cloudtolocalllm/models/agent.dart';
import 'package:cloudtolocalllm/models/agent_event.dart';
import 'package:cloudtolocalllm/services/dashboard_service.dart';
import 'package:cloudtolocalllm/providers/agent_provider.dart';

/// Main dashboard screen with tabs for different views
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DashboardService _dashboardService = DashboardService();
  List<Agent> _agents = [];
  List<AgentEvent> _events = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final agents = await _dashboardService.getAgents();
      final events = await _dashboardService.getRecentEvents(limit: 50);

      // Update provider
      if (mounted) {
        context.read<AgentProvider>().setAgents(agents);
      }

      setState(() {
        _agents = agents;
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    _dashboardService.connectWebSocket(
      onData: (data) {
        if (!mounted) return;

        switch (data['type']) {
          case 'agent_update':
            _handleAgentUpdate(data['agent']);
            break;
          case 'event_stream':
            _handleNewEvent(data['event']);
            break;
          case 'agent_spawn':
          case 'agent_terminate':
            _loadData(); // Refresh agent list
            break;
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = 'WebSocket error: $error';
          });
        }
      },
    );
  }

  void _handleAgentUpdate(Map<String, dynamic> data) {
    final agent = Agent.fromJson(data);
    context.read<AgentProvider>().updateAgent(agent);

    setState(() {
      final index = _agents.indexWhere((a) => a.agentId == agent.agentId);
      if (index >= 0) {
        _agents[index] = agent;
      } else {
        _agents.add(agent);
      }
    });
  }

  void _handleNewEvent(Map<String, dynamic> eventData) {
    final event = AgentEvent.fromJson(eventData);

    setState(() {
      _events.insert(0, event);
      if (_events.length > 100) _events.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'spawn_agent') {
                _showSpawnAgentDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'spawn_agent',
                child: ListTile(
                  leading: Icon(Icons.add_circle),
                  title: Text('Spawn Agent'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Agents', icon: Icon(Icons.people)),
            Tab(text: 'Events', icon: Icon(Icons.event_note)),
            Tab(text: 'Resources', icon: Icon(Icons.dashboard)),
            Tab(text: 'Metrics', icon: Icon(Icons.bar_chart)),
          ],
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard...',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading dashboard',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        AgentListView(
          agents: _agents,
          onAgentTap: _showAgentDetails,
        ),
        EventStreamScreen(events: _events),
        const ResourceOverviewScreen(),
        MetricsView(agents: _agents),
      ],
    );
  }

  void _showAgentDetails(Agent agent) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentDetailScreen(agent: agent),
      ),
    );
  }

  void _showSpawnAgentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spawn New Agent'),
        content: const Text('Agent spawning form - to be implemented'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement spawn agent logic
            },
            child: const Text('Spawn'),
          ),
        ],
      ),
    );
  }
}

/// Simple metrics view widget
class MetricsView extends StatelessWidget {
  final List<Agent> agents;

  const MetricsView({super.key, required this.agents});

  @override
  Widget build(BuildContext context) {
    final activeAgents = agents.where((a) => a.status == 'active').length;
    final errorAgents = agents.where((a) => a.status == 'error').length;
    final offlineAgents = agents.where((a) => a.status == 'offline').length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agent Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MetricCard(
                      label: 'Total',
                      value: '${agents.length}',
                      color: Colors.blue,
                      icon: Icons.people,
                    ),
                    _MetricCard(
                      label: 'Active',
                      value: '$activeAgents',
                      color: Colors.green,
                      icon: Icons.play_circle,
                    ),
                    _MetricCard(
                      label: 'Errors',
                      value: '$errorAgents',
                      color: Colors.red,
                      icon: Icons.error,
                    ),
                    _MetricCard(
                      label: 'Offline',
                      value: '$offlineAgents',
                      color: Colors.grey,
                      icon: Icons.cloud_off,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }
}
