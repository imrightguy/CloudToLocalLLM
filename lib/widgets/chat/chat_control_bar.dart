import 'package:flutter/material.dart';

import 'session_selector.dart';

class ChatControlBar extends StatelessWidget {
  final String currentSession;
  final bool isConnected;
  final ValueChanged<String> onSessionChanged;
  final VoidCallback onRefresh;
  final ValueChanged<bool> onThinkingToggle;
  final ValueChanged<bool> onFocusModeToggle;
  final ValueChanged<bool> onCronSessionsToggle;
  final bool showThinking;
  final bool focusMode;
  final bool showCronSessions;

  const ChatControlBar({
    required this.currentSession,
    required this.isConnected,
    required this.onSessionChanged,
    required this.onRefresh,
    required this.onThinkingToggle,
    required this.onFocusModeToggle,
    required this.onCronSessionsToggle,
    this.showThinking = true,
    this.focusMode = false,
    this.showCronSessions = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Session selector
          Expanded(
            child: SessionSelector(
              currentSession: currentSession,
              onSessionChanged: onSessionChanged,
              enabled: isConnected,
            ),
          ),
          const SizedBox(width: 16),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isConnected ? onRefresh : null,
            tooltip: 'Refresh chat data',
          ),
          const Text('|'),

          // Toggle thinking output
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed:
                isConnected ? () => onThinkingToggle(!showThinking) : null,
            tooltip: 'Toggle assistant thinking/working output',
            style: IconButton.styleFrom(
              backgroundColor: showThinking
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
          ),

          // Toggle focus mode
          IconButton(
            icon: const Icon(Icons.fullscreen_outlined),
            onPressed: isConnected ? () => onFocusModeToggle(!focusMode) : null,
            tooltip: 'Toggle focus mode (hide sidebar + page header)',
            style: IconButton.styleFrom(
              backgroundColor: focusMode
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
          ),

          // Toggle cron sessions
          IconButton(
            icon: const Icon(Icons.schedule_outlined),
            onPressed: isConnected
                ? () => onCronSessionsToggle(!showCronSessions)
                : null,
            tooltip: 'Show cron sessions',
            style: IconButton.styleFrom(
              backgroundColor: showCronSessions
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
