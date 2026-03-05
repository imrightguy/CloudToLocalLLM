library;

import 'package:flutter/material.dart';

import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/navigation/popout_button.dart';
// TODO: Uncomment when integrating with actual services
// import '../../services/subagent_registry_service.dart';
// import '../../di/locator.dart' as di;

/// Screen displaying skills management with three tabs
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // TODO: Integrate with actual services
  // final SubagentRegistryService _subagentRegistry =
  //     di.serviceLocator<SubagentRegistryService>();

  List<dynamic> _skills = [];

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
      // TODO: Fetch skills from registry
      // _skills = await _subagentRegistry.listSkills();

      // TODO: Fetch usage metrics
      // final usageMetrics = await _subagentRegistry.getSkillUsageMetrics();

      _skills = [];

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load skills: $e';
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
          title: const Text('Skills'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _onRefresh,
            ),
            PopOutButton(sectionName: 'skills', branchIndex: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registry'),
              Tab(text: 'Usage'),
              Tab(text: 'Management'),
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
                      _buildUsageTab(),
                      _buildManagementTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildRegistryTab() {
    // TODO: Display skills from SubagentRegistryService
    if (_skills.isEmpty) {
      return const EmptyState(
        icon: Icons.extension,
        title: 'No Skills Registered',
        message: 'Skills will appear here when registered',
      );
    }

    return ListView.builder(
      itemCount: _skills.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text('Skill $index'),
            subtitle: const Text('TODO: Load from SubagentRegistryService'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // TODO: Enable/disable skill
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsageTab() {
    // TODO: Display usage metrics with charts
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Skill Usage Analytics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Chart placeholder'),
        ],
      ),
    );
  }

  Widget _buildManagementTab() {
    // TODO: Implement skill parameter configuration
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Skill Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Configure timeouts, retries, and parameters'),
        ],
      ),
    );
  }
}
