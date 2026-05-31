import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cloudtolocalllm/services/connection_manager_service.dart';
import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';

class OpenVoiceUIControlPanel extends StatelessWidget {
  const OpenVoiceUIControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConnectionManagerService, VoiceConversationService, LocalVoiceInputService>(
      builder: (context, connectionManager, voiceService, localVoice, child) {
        final backend = connectionManager.activeBackend;
        final gatewayStatus = connectionManager.getGatewayStatus();
        final backendLabel =
            gatewayStatus['backendLabel']?.toString() ?? 'Unknown backend';
        final backendState = gatewayStatus['state']?.toString() ?? 'unknown';
        final isRunning = gatewayStatus['isRunning'] == true;
        final isConnected = gatewayStatus['isConnected'] == true;
        final voiceSnapshot = voiceService.snapshot;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? (isRunning ? Colors.greenAccent : Colors.orange)
                            : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OpenVoiceUI Control',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      backendLabel,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Voice front-end, agent control, and backend switching in one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatusChip(
                      label: 'Backend',
                      value: backendLabel,
                    ),
                    _StatusChip(
                      label: 'State',
                      value: backendState,
                    ),
                    _StatusChip(
                      label: 'Voice mode',
                      value: voiceSnapshot.mode.name,
                    ),
                    _StatusChip(
                      label: 'Listening',
                      value:
                          voiceSnapshot.liveBridgeConnected ? 'live' : 'local',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BackendButton(
                      label: 'OpenClaw',
                      selected: backend == BackendType.openclaw,
                      onPressed: () => _switchBackend(
                        context,
                        connectionManager,
                        BackendType.openclaw,
                      ),
                    ),
                    _BackendButton(
                      label: 'Hermes Agent',
                      selected: backend == BackendType.hermes,
                      onPressed: () => _switchBackend(
                        context,
                        connectionManager,
                        BackendType.hermes,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await connectionManager.testConnection();
                        if (!context.mounted) {
                          return;
                        }
                        _showFeedback(
                          context,
                          ok
                              ? 'Connection looks healthy.'
                              : 'Connection test failed.',
                          ok,
                        );
                      },
                      icon: const Icon(Icons.health_and_safety),
                      label: const Text('Test'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        voiceService.reset();
                        _showFeedback(context, 'Voice state reset.', true);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset voice'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!kIsWeb)
                  _RuntimeControls(
                    backendLabel: backendLabel,
                    isRunning: isRunning,
                    onStart: () => _runGatewayAction(
                      context,
                      connectionManager,
                      GatewayAction.start,
                    ),
                    onStop: () => _runGatewayAction(
                      context,
                      connectionManager,
                      GatewayAction.stop,
                    ),
                    onRestart: () => _runGatewayAction(
                      context,
                      connectionManager,
                      GatewayAction.restart,
                    ),
                  )
                else
                  Text(
                    'Gateway process controls are only available on desktop builds.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text(
                  'Local Mic',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: localVoice.isCapturing
                          ? null
                          : () => _toggleMic(context, localVoice),
                      icon: const Icon(Icons.mic),
                      label: const Text('Listen'),
                    ),
                    ElevatedButton.icon(
                      onPressed: localVoice.isCapturing
                          ? () => _toggleMic(context, localVoice)
                          : null,
                      icon: const Icon(Icons.mic_off),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                        foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                    _StatusChip(
                      label: 'Mic',
                      value: localVoice.isCapturing ? 'ON' : 'OFF',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _TranscriptPreview(
                  title: 'Last heard',
                  value: voiceSnapshot.lastUserTranscript,
                  emptyLabel: 'No voice input yet',
                ),
                const SizedBox(height: 12),
                _TranscriptPreview(
                  title: 'Last reply',
                  value: voiceSnapshot.lastAssistantReply,
                  emptyLabel: 'No voice reply yet',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleMic(
    BuildContext context,
    LocalVoiceInputService localVoice,
  ) async {
    if (localVoice.isCapturing) {
      await localVoice.stopCapture();
      if (!context.mounted) return;
      _showFeedback(context, 'Mic off', true);
    } else {
      final ok = await localVoice.startCapture();
      if (!context.mounted) return;
      if (ok) {
        _showFeedback(context, 'Mic on — listening...', true);
      } else {
        _showFeedback(
          context,
          localVoice.snapshot.lastError ?? 'Failed to start mic',
          false,
        );
      }
    }
  }

  Future<void> _switchBackend(
    BuildContext context,
    ConnectionManagerService connectionManager,
    BackendType backend,
  ) async {
    if (connectionManager.activeBackend == backend) {
      _showFeedback(
        context,
        backend == BackendType.hermes
            ? 'Hermes is already selected.'
            : 'OpenClaw is already selected.',
        true,
      );
      return;
    }

    connectionManager.switchBackend(backend);
    final ok = await connectionManager.testConnection();
    if (!context.mounted) {
      return;
    }
    _showFeedback(
      context,
      ok ? 'Switched backend successfully.' : 'Backend switch needs attention.',
      ok,
    );
  }

  Future<void> _runGatewayAction(
    BuildContext context,
    ConnectionManagerService connectionManager,
    GatewayAction action,
  ) async {
    bool ok = false;
    switch (action) {
      case GatewayAction.start:
        ok = await connectionManager.startActiveGateway();
        break;
      case GatewayAction.stop:
        ok = await connectionManager.stopActiveGateway();
        break;
      case GatewayAction.restart:
        ok = await connectionManager.restartActiveGateway();
        break;
    }

    if (!context.mounted) {
      return;
    }

    _showFeedback(
      context,
      switch (action) {
        GatewayAction.start => ok ? 'Backend started.' : 'Start failed.',
        GatewayAction.stop => ok ? 'Backend stopped.' : 'Stop failed.',
        GatewayAction.restart => ok ? 'Backend restarted.' : 'Restart failed.',
      },
      ok,
    );
  }

  void _showFeedback(BuildContext context, String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}

enum GatewayAction {
  start,
  stop,
  restart,
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _BackendButton extends StatelessWidget {
  const _BackendButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon:
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor:
            selected ? Theme.of(context).colorScheme.primaryContainer : null,
        foregroundColor:
            selected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
      ),
    );
  }
}

class _RuntimeControls extends StatelessWidget {
  const _RuntimeControls({
    required this.backendLabel,
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    required this.onRestart,
  });

  final String backendLabel;
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$backendLabel runtime',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: isRunning ? null : onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            ),
            ElevatedButton.icon(
              onPressed: isRunning ? onStop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
            OutlinedButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Restart'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview({
    required this.title,
    required this.value,
    required this.emptyLabel,
  });

  final String title;
  final String value;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(
                  alpha: 0.35,
                ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            hasValue ? value : emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: hasValue ? null : Colors.grey,
                  fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }
}
