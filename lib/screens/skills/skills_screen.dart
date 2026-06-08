/// Screen displaying skills management with three tabs
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

/// Skill model for displaying in the registry
class Skill {
  final String id;
  final String name;
  final String description;
  final String category;
  final bool enabled;
  final int usageCount;
  final double avgResponseTime;
  final DateTime lastUsed;

  const Skill({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.enabled,
    this.usageCount = 0,
    this.avgResponseTime = 0.0,
    required this.lastUsed,
  });
}

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

  List<Skill> _skills = [];
  Map<String, int> _skillUsage = {};

  // TODO: Integrate with actual services
  // final SubagentRegistryService _subagentRegistry =
  //     di.serviceLocator<SubagentRegistryService>();

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
      await Future.delayed(const Duration(milliseconds: 300));

      // Mock skills data
      _skills = [
        Skill(
          id: 'code-reviewer',
          name: 'Code Reviewer',
          description:
              'Analyzes code for bugs, security issues, and best practices',
          category: 'Development',
          enabled: true,
          usageCount: 47,
          avgResponseTime: 2.3,
          lastUsed: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        Skill(
          id: 'summarizer',
          name: 'Text Summarizer',
          description: 'Condenses long documents into concise summaries',
          category: 'Text Processing',
          enabled: true,
          usageCount: 123,
          avgResponseTime: 1.8,
          lastUsed: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        Skill(
          id: 'file-scanner',
          name: 'File Scanner',
          description: 'Scans directories for specific file patterns',
          category: 'Utilities',
          enabled: true,
          usageCount: 28,
          avgResponseTime: 0.9,
          lastUsed: DateTime.now().subtract(const Duration(days: 1)),
        ),
        Skill(
          id: 'translator',
          name: 'Multi-language Translator',
          description: 'Translates text between multiple languages',
          category: 'Text Processing',
          enabled: false,
          usageCount: 15,
          avgResponseTime: 2.1,
          lastUsed: DateTime.now().subtract(const Duration(days: 5)),
        ),
        Skill(
          id: 'data-analyzer',
          name: 'Data Analyzer',
          description: 'Performs statistical analysis on datasets',
          category: 'Data Science',
          enabled: true,
          usageCount: 34,
          avgResponseTime: 3.5,
          lastUsed: DateTime.now().subtract(const Duration(hours: 6)),
        ),
        Skill(
          id: 'image-processor',
          name: 'Image Processor',
          description: 'Applies filters and transformations to images',
          category: 'Media',
          enabled: false,
          usageCount: 8,
          avgResponseTime: 4.2,
          lastUsed: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ];

      _skillUsage = {
        'Development': 81,
        'Text Processing': 138,
        'Utilities': 28,
        'Data Science': 34,
        'Media': 8,
      };

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

  void _toggleSkill(Skill skill) {
    setState(() {
      final index = _skills.indexWhere((s) => s.id == skill.id);
      if (index != -1) {
        _skills[index] = Skill(
          id: skill.id,
          name: skill.name,
          description: skill.description,
          category: skill.category,
          enabled: !skill.enabled,
          usageCount: skill.usageCount,
          avgResponseTime: skill.avgResponseTime,
          lastUsed: skill.lastUsed,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('${skill.name} ${!skill.enabled ? 'enabled' : 'disabled'}'),
        duration: const Duration(seconds: 2),
      ),
    );
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
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Register new skill - coming soon')),
                );
              },
              tooltip: 'Register Skill',
            ),
            PopOutButton(sectionName: 'skills', branchIndex: 8),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Registry', icon: Icon(Icons.extension_outlined)),
              Tab(text: 'Usage', icon: Icon(Icons.bar_chart)),
              Tab(text: 'Management', icon: Icon(Icons.settings)),
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
    if (_skills.isEmpty) {
      return const EmptyState(
        icon: Icons.extension,
        title: 'No Skills Registered',
        message: 'Skills will appear here when registered',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _skills.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final skill = _skills[index];
        return _buildSkillCard(skill);
      },
    );
  }

  Widget _buildSkillCard(Skill skill) {
    final theme = Theme.of(context);

    return Card(
      elevation: skill.enabled ? 2 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(skill.category),
                  size: 32,
                  color: skill.enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              skill.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: skill.enabled
                                    ? null
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(skill.category),
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        skill.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: skill.enabled,
                  onChanged: (_) => _toggleSkill(skill),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStat(
                    Icons.play_arrow, skill.usageCount.toString(), 'Uses'),
                const SizedBox(width: 16),
                _buildStat(Icons.schedule,
                    '${skill.avgResponseTime.toStringAsFixed(1)}s', 'Avg Time'),
                const SizedBox(width: 16),
                _buildStat(Icons.access_time, _formatLastUsed(skill.lastUsed),
                    'Last Used'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 14,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
        ),
      ],
    );
  }

  Widget _buildUsageTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skill Usage by Category',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          ..._skillUsage.entries.map((entry) {
            final maxUsage = _skillUsage.values.reduce((a, b) => a > b ? a : b);
            final percentage = entry.value / maxUsage;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key,
                          style: Theme.of(context).textTheme.bodyLarge),
                      Text('${entry.value} uses',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: percentage,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 32),
          Text(
            'Top Performing Skills',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...(_skills.where((s) => s.enabled).toList()
                ..sort((a, b) => a.usageCount.compareTo(b.usageCount)))
              .reversed
              .take(3)
              .map((skill) => ListTile(
                    leading: Icon(_getCategoryIcon(skill.category)),
                    title: Text(skill.name),
                    subtitle: Text(
                        '${skill.usageCount} uses • ${skill.avgResponseTime}s avg'),
                  )),
        ],
      ),
    );
  }

  Widget _buildManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text('Global Settings',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Auto-disable slow skills'),
                    subtitle: const Text(
                        'Disable skills that take longer than 5 seconds'),
                    value: true,
                    onChanged: (value) {},
                  ),
                  SwitchListTile(
                    title: const Text('Cache skill results'),
                    subtitle:
                        const Text('Store responses for identical requests'),
                    value: true,
                    onChanged: (value) {},
                  ),
                  ListTile(
                    title: const Text('Default timeout'),
                    subtitle: const Text('30 seconds'),
                    trailing: const Text('30s'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, size: 20),
                      const SizedBox(width: 8),
                      Text('Resource Limits',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Max concurrent skills'),
                    subtitle:
                        const Text('Maximum skills running simultaneously'),
                    trailing: const Text('5'),
                    onTap: () {},
                  ),
                  ListTile(
                    title: const Text('Memory per skill'),
                    subtitle: const Text('Maximum RAM allocation per skill'),
                    trailing: const Text('512 MB'),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'text processing':
        return Icons.text_snippet;
      case 'utilities':
        return Icons.build;
      case 'data science':
        return Icons.analytics;
      case 'media':
        return Icons.image;
      default:
        return Icons.extension;
    }
  }

  String _formatLastUsed(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dt.month}/${dt.day}';
    }
  }
}
