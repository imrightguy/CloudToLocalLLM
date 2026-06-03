import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/voice/voice_conversation_service.dart';
import '../../services/voice/local_voice_input_service.dart';

class VoiceConversationStatusCard extends StatefulWidget {
  const VoiceConversationStatusCard({
    super.key,
    this.showDemoControls = false,
  });

  final bool showDemoControls;

  @override
  State<VoiceConversationStatusCard> createState() =>
      _VoiceConversationStatusCardState();
}

class _VoiceConversationStatusCardState
    extends State<VoiceConversationStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceConversationService>(
      builder: (context, voiceService, child) {
        final snapshot = voiceService.snapshot;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final modeColor = _modeColor(snapshot.mode, scheme);
        final modeLabel = _modeLabel(snapshot.mode);
        final shouldPulse = snapshot.mode != VoiceConversationMode.idle &&
            snapshot.mode != VoiceConversationMode.coolingDown;

        if (shouldPulse && !_pulseController.isAnimating) {
          _pulseController.repeat(reverse: true);
        } else if (!shouldPulse && _pulseController.isAnimating) {
          _pulseController.stop();
          _pulseController.reset();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Pulsing status indicator
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: modeColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: modeColor.withValues(alpha: 0.4),
                                  blurRadius: 10 * _pulseAnimation.value,
                                  spreadRadius: 2 * _pulseAnimation.value,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Voice Conversation',
                        style: theme.textTheme.titleMedium,
                      ),
                      const Spacer(),
                      _ModeBadge(
                        modeLabel: modeLabel,
                        modeColor: modeColor,
                        theme: theme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Low-latency voice shell state for natural back-and-forth around Hermes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _InfoChip(
                        label: 'Bridge',
                        value: snapshot.liveBridgeConnected
                            ? snapshot.liveBridgeStatus
                            : 'offline',
                      ),
                      _InfoChip(
                        label: 'Engaged',
                        value: snapshot.isEngaged ? 'yes' : 'no',
                      ),
                      _InfoChip(
                        label: 'Hold until',
                        value: _formatUntil(snapshot.engagedUntil),
                      ),
                      // Optional mic status chip — reads from LocalVoiceInputService if available
                      _MicStatusChip(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.transcriptInProgress.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AnimatedTranscriptPanel(
                        title: 'Processing...',
                        value: snapshot.transcriptInProgress,
                        emptyLabel: '',
                      ),
                    ),
                  _AnimatedTranscriptPanel(
                    title: 'Last heard',
                    value: snapshot.lastUserTranscript,
                    emptyLabel: 'No transcript yet',
                  ),
                  const SizedBox(height: 12),
                  _AnimatedTranscriptPanel(
                    title: 'Last reply',
                    value: snapshot.lastAssistantReply,
                    emptyLabel: 'No reply yet',
                  ),
                  if (widget.showDemoControls) ..._buildDemoControls(voiceService, theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildDemoControls(VoiceConversationService voiceService, ThemeData theme) {
    return [
      const SizedBox(height: 16),
      const Divider(height: 1),
      const SizedBox(height: 16),
      Text(
        'Demo controls',
        style: theme.textTheme.titleSmall,
      ),
      const SizedBox(height: 6),
      Text(
        'Use these to fake a voice exchange while wiring the real mic path.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: Colors.grey,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              voiceService.setListening();
            },
            icon: const Icon(Icons.hearing),
            label: const Text('Listening'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              voiceService.noteWakePhrase('Zoidbot, are you there?');
            },
            icon: const Icon(Icons.record_voice_over),
            label: const Text('Wake'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              voiceService.noteUserTranscript(
                'Can you hear me properly now?',
              );
            },
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('User line'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              voiceService.noteAssistantReply('Yeah, much better now.');
            },
            icon: const Icon(Icons.reply),
            label: const Text('Assistant reply'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              voiceService.noteAssistantFinishedSpeaking();
            },
            icon: const Icon(Icons.volume_up),
            label: const Text('Done speaking'),
          ),
          TextButton.icon(
            onPressed: () {
              voiceService.reset();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ],
      ),
    ];
  }

  String _modeLabel(VoiceConversationMode mode) {
    switch (mode) {
      case VoiceConversationMode.idle:
        return 'idle';
      case VoiceConversationMode.listening:
        return 'listening';
      case VoiceConversationMode.engaged:
        return 'engaged';
      case VoiceConversationMode.speaking:
        return 'speaking';
      case VoiceConversationMode.coolingDown:
        return 'cooldown';
    }
  }

  Color _modeColor(VoiceConversationMode mode, ColorScheme scheme) {
    switch (mode) {
      case VoiceConversationMode.idle:
        return scheme.outline;
      case VoiceConversationMode.listening:
        return scheme.primary;
      case VoiceConversationMode.engaged:
        return Colors.greenAccent.shade400;
      case VoiceConversationMode.speaking:
        return Colors.orangeAccent.shade400;
      case VoiceConversationMode.coolingDown:
        return scheme.secondary;
    }
  }

  String _formatUntil(DateTime? engagedUntil) {
    if (engagedUntil == null) {
      return 'n/a';
    }
    final remaining = engagedUntil.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      return 'expired';
    }
    return '${remaining}s';
  }
}

/// Animated mode badge that fades between labels on transition.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({
    required this.modeLabel,
    required this.modeColor,
    required this.theme,
  });

  final String modeLabel;
  final Color modeColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: modeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Text(
          modeLabel,
          key: ValueKey(modeLabel),
          style: theme.textTheme.labelMedium?.copyWith(
            color: modeColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Mic status chip that reads from [LocalVoiceInputService] if available.
class _MicStatusChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Attempt to read mic service — optional, gracefully falls back to OFF
    try {
      final micService = context.read<LocalVoiceInputService>();
      final capturing = micService.isCapturing;
      return _InfoChip(
        label: 'Mic',
        value: capturing ? 'ON' : 'OFF',
      );
    } catch (_) {
      // No LocalVoiceInputService in the tree — show OFF by default
      return _InfoChip(
        label: 'Mic',
        value: 'OFF',
      );
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

/// Transcript panel with animated transitions on content change.
class _AnimatedTranscriptPanel extends StatelessWidget {
  const _AnimatedTranscriptPanel({
    required this.title,
    required this.value,
    required this.emptyLabel,
  });

  final String title;
  final String value;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasValue
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) {
              return FadeTransition(opacity: animation, child: child);
            },
            child: Text(
              hasValue ? value : emptyLabel,
              key: ValueKey(hasValue ? value : 'empty:$title'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: hasValue ? null : Colors.grey,
                fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
