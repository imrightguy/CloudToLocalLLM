import 'package:flutter/material.dart';

/// Construction Page - Shows current features with progress and roadmap
class ConstructionScreen extends StatelessWidget {
  const ConstructionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Construction'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt, color: Colors.white, size: 24),
                      SizedBox(width: 12),
                      Text(
                        'Beta / Active Development',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We are building something amazing. Check back soon!',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Current Features
            Text(
              'Current Features',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildFeatureCard(
              context,
              title: 'Agent Dashboard',
              description: 'Real-time visibility into all your AI agents',
              progress: 90,
              icon: Icons.dashboard,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Local LLM Support',
              description: 'Run powerful AI models locally with OpenClaw',
              progress: 95,
              icon: Icons.memory,
              color: Colors.green,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Privacy-First',
              description: 'Your data stays on your device unless you enable cloud relay',
              progress: 100,
              icon: Icons.shield,
              color: Colors.purple,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              context,
              title: 'Multi-Platform',
              description: 'Linux, Windows, macOS, and Web support',
              progress: 85,
              icon: Icons.devices,
              color: Colors.orange,
            ),
            const SizedBox(height: 32),

            // Roadmap Timeline
            Text(
              'Roadmap',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildRoadmapCard(
              context,
              title: 'Phase 1: Foundation',
              description: 'Agent Dashboard polish, retry logic, error handling',
              date: 'Completed',
              isCompleted: true,
              items: ['✓ Agent Dashboard v1', '✓ Retry/Backoff Logic', '✓ Error Handling', '✓ Configurable URLs'],
            ),
            const SizedBox(height: 12),

            _buildRoadmapCard(
              context,
              title: 'Phase 2: Mobile Experience',
              description: 'Location-aware agents, offline optimization',
              date: 'Q2 2026',
              isCompleted: false,
              items: ['📱 Follow Mode', '📍 Geofencing', '⚡ Offline Mode', '🔔 Push Notifications'],
            ),
            const SizedBox(height: 12),

            _buildRoadmapCard(
              context,
              title: 'Phase 3: Cloud Integrations',
              description: 'Google Workspace, Apple Ecosystem, Health APIs',
              date: 'Q3 2026',
              isCompleted: false,
              items: ['📧 Gmail Integration', '📅 Calendar Sync', '📱 HealthKit Access', '🚀 Production Deployment'],
            ),
            const SizedBox(height: 32),

            // Quick Links
            Text(
              'Quick Links',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),

            _buildLinkCard(
              context,
              title: 'GitHub Repository',
              description: 'View code, report issues, contribute',
              url: 'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM',
              icon: Icons.code,
            ),
            const SizedBox(height: 12),

            _buildLinkCard(
              context,
              title: 'Documentation',
              description: 'Learn how to use CloudToLocalLLM',
              url: 'https://docs.cloudtolocalllm.online',
              icon: Icons.book,
            ),
            const SizedBox(height: 12),

            _buildLinkCard(
              context,
              title: 'Discord Community',
              description: 'Join discussions, get support',
              url: 'https://discord.gg/clawd',
              icon: Icons.discord,
            ),
            const SizedBox(height: 32),

            // Back Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to App'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required String description,
    required int progress,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$progress%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard(
    BuildContext context, {
    required String title,
    required String description,
    required String date,
    required bool isCompleted,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isCompleted ? Icons.check_circle : Icons.event,
                    color: isCompleted ? Colors.green : Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        date,
                        style: TextStyle(
                          fontSize: 12,
                          color: isCompleted
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isCompleted ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: isCompleted ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(item),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkCard(
    BuildContext context, {
    required String title,
    required String description,
    required String url,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title),
        subtitle: Text(description),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.outline,
        ),
        onTap: () {
          // Open link in new tab
          // In Flutter web, this works; in desktop apps, it might need platform-specific code
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $url...'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
