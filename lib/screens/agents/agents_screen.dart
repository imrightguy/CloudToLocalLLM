library;

import 'package:flutter/material.dart';

import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/navigation/popout_button.dart';
// TODO: Uncomment when integrating with actual services
// import '../../services/subagent_registry_service.dart';
// import '../../services/agent_status_service.dart';
// import '../../services/agent_lifecycle_service.dart';
// import '../../di/locator.dart' as di;

/// Screen displaying agent management with three tabs
class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // TODO: Integrate with actual services
  // final SubagentRegistryService _subagentRegistry =
  //     di.serviceLocator<SubagentRegistryService>();
  // final AgentStatusService _agentStatus = di.serviceLocator<AgentStatusService>();
  // final AgentLifecycleService _agentLifecycle =
  //     di.serviceLocator<AgentLifecycleService>();

  List<dynamic> _agents = [];
  List<dynamic> _activityFeed = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Fetch from SubagentRegistryService
      // _agents = await _subagentRegistry.listSubagents();

      // TODO: Fetch from AgentStatusService.statusStream
      // _activityFeed = await _agentStatus.getCurrentStatuses();

      _agents = [];
      _activityFeed = [];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load agents: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Agents'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
            ),
            PopOutButton(sectionName: 'agents', branchIndex: 7),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registry'),
              Tab(text: 'Monitor'),
              Tab(text: 'Config'),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 200)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRegistryTab(),
                      _buildMonitorTab(),
                      _buildConfigTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab() {
    // TODO: Display agents from SubagentRegistryService
    if (_agents.isEmpty) {
      return const EmptyState(
        icon: Icons.people,
        title: 'No Agents Registered',
        message: 'Agents will appear here when registered',
      );
    }

    return ListView.builder(
      itemCount: _agents.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text('Agent $index'),
            subtitle: const Text('TODO: Load from SubagentRegistryService'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.visibility), onPressed: () {}),
                IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {}),
                IconButton(icon: const Icon(Icons.stop), onPressed: () {}),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonitorTab() {
    // TODO: Display live activity from AgentStatusService.statusStream
    if (_activityFeed.isEmpty) {
      return const EmptyState(
        icon: Icons.monitor_heart,
        title: 'No Activity',
        message: 'Agent activity will appear here',
      );
    }

    return ListView.builder(
      itemCount: _activityFeed.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text('Event $index'),
            subtitle: const Text('TODO: Load from AgentStatusService'),
            trailing: const Text('Just now'),
          ),
        );
      },
    );
  }

  Widget _buildConfigTab() {
    // TODO: Implement agent configuration forms
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Agent Configuration',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Configuration forms coming soon'),
        ],
      ),
    );
  }
}
