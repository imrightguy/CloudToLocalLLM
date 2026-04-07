library;

import 'package:flutter/material.dart';
import '../../models/node.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/navigation/popout_button.dart';

/// Screen displaying local and cloud nodes for OpenClaw Gateway
class NodesScreen extends StatefulWidget {
  const NodesScreen({super.key});
  @override
  State<NodesScreen> createState() => _NodesScreenState();
}

class _NodesScreenState extends State<NodesScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Node> _localNodes = [];
  List<Node> _cloudNodes = [];

  // TODO: Integrate with actual services
  // final ProviderDiscoveryService _discovery =
  //     di.serviceLocator<ProviderDiscoveryService>();
  // final ConnectionManagerService _connectionManager =
  //     di.serviceLocator<ConnectionManagerService>();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Fetch from ProviderDiscoveryService and ConnectionManagerService
      _localNodes = [
        Node(
            id: 'openclaw_local',
            name: 'OpenClaw Gateway',
            type: 'local',
            status: 'online',
            latency: 12,
            tier: 'critical')
      ];
      _cloudNodes = [];
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load nodes: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async => await _loadData();

  @override
  Widget build(BuildContext context) {
    return RefreshableScreen(
      onRefresh: _onRefresh,
      child: Scaffold(
        appBar: AppBar(title: const Text('Nodes'), actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _onRefresh),
          PopOutButton(sectionName: 'nodes', branchIndex: 9)
        ]),
        body: _isLoading
            ? const LoadingSkeleton(itemCount: 3, height: 120)
            : _errorMessage != null
                ? ErrorState(message: _errorMessage!, onRetry: _onRefresh)
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(children: [
                      CardSection(
                          title: 'Local Nodes',
                          children: _buildNodesList(_localNodes)),
                      CardSection(
                          title: 'Cloud Nodes',
                          children: _buildNodesList(_cloudNodes))
                    ])),
        floatingActionButton: FloatingActionButton(
            onPressed: () => _addNodeDialog(context),
            tooltip: 'Add Node',
            child: const Icon(Icons.add)),
      ),
    );
  }

  List<Widget> _buildNodesList(List<Node> nodes) => nodes.isEmpty
      ? [
          const Padding(
              padding: EdgeInsets.all(16), child: Text('No nodes discovered'))
        ]
      : [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      nodes.map((node) => _NodeCard(node: node)).toList()))
        ];

  Future<void> _addNodeDialog(BuildContext context) async => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
              title: const Text('Add Node'),
              content: const Text('Node configuration coming soon'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'))
              ]));
}

class _NodeCard extends StatelessWidget {
  final Node node;
  const _NodeCard({required this.node});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = node.status == 'online';
    return Card(
        child: Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(isOnline ? Icons.check_circle : Icons.error,
                    color: isOnline ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(node.name,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)))
              ]),
              const SizedBox(height: 8),
              if (node.latency != null)
                Row(children: [
                  const Icon(Icons.speed, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${node.latency}ms', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4)
                ]),
              if (node.tier != null)
                Chip(
                    label: Text(node.tier!, style: theme.textTheme.labelSmall),
                    visualDensity: VisualDensity.compact),
              Row(children: [
                const Icon(Icons.numbers, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text('${node.activeRequestCount} active',
                    style: theme.textTheme.bodySmall)
              ])
            ])));
  }
}
