import 'package:flutter/material.dart';
import '../database/local_brain.dart';
import '../di/locator.dart';

/// A dashboard widget that displays the internal "thoughts" and logs of the AI agent.
class BrainInsightWidget extends StatelessWidget {
  const BrainInsightWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localBrain = serviceLocator.get<LocalBrain>();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Local Brain Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                const Chip(
                  label: Text('HIGH SPEED (RAM)'),
                  backgroundColor: Colors.greenAccent,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<AgentLog>>(
              // Note: Stream logic will be added to LocalBrain later
              stream: Stream.periodic(const Duration(seconds: 2)).asyncMap(
                  (_) => localBrain.select(localBrain.agentLogs).get()),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Center(
                      child: Text('No internal logs recorded yet.'));
                }

                return ListView.separated(
                  itemCount: logs.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log =
                        logs[logs.length - 1 - index]; // Reverse chronological
                    return ListTile(
                      dense: true,
                      leading: _getLogLevelIcon(log.level),
                      title: Text(log.message),
                      subtitle: Text(
                        '${log.timestamp.toIso8601String()} | ${log.context ?? ""}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getLogLevelIcon(String level) {
    return switch (level.toLowerCase()) {
      'error' => const Icon(Icons.error, color: Colors.red, size: 20),
      'warn' => const Icon(Icons.warning, color: Colors.orange, size: 20),
      _ => const Icon(Icons.info, color: Colors.blue, size: 20),
    };
  }
}
