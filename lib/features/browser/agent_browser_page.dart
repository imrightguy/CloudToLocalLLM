/// Agent Browser Page
///
/// A prototype browser page for agent web interactions.
/// Note: flutter_inappwebview is not currently included in dependencies.
/// This is a stub implementation.
library;

import 'package:flutter/material.dart';

class AgentBrowserPage extends StatefulWidget {
  const AgentBrowserPage({super.key});

  @override
  State<AgentBrowserPage> createState() => _AgentBrowserPageState();
}

class _AgentBrowserPageState extends State<AgentBrowserPage> {
  final TextEditingController urlController =
      TextEditingController(text: 'https://www.google.com');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Browser (Stub)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Stub - no-op
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Browser functionality not available')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      hintText: 'Enter URL',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) {
                      // Stub - no-op
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () {
                    // Stub - no-op
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Browser functionality not available')),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.web_asset_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Browser functionality is not available',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add flutter_inappwebview to pubspec.yaml to enable',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    urlController.dispose();
    super.dispose();
  }
}
