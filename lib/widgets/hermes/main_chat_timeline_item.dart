import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MainChatTimelineItem extends StatelessWidget {
  const MainChatTimelineItem({
    required this.event,
    this.showVerboseDetails = false,
    super.key,
  });

  final MainChatTimelineEvent event;
  final bool showVerboseDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _colorForEvent(event, scheme);
    final icon = _iconForEvent(event);
    final label = _labelForEvent(event);
    final primaryText = _primaryText;
    final verboseBody = _verboseBody;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusPill(
                        label: label,
                        color: color,
                      ),
                    ],
                  ),
                  if (primaryText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      primaryText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  if (verboseBody != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      verboseBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (_detailChips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _detailChips
                          .map(
                            (label) => _MetadataChip(
                              label: label,
                              color: color,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (event.artifactPath != null) ...[
                    const SizedBox(height: 8),
                    _ArtifactChip(
                      fileName: _basename(event.artifactPath!),
                      color: color,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _primaryText {
    final summary = event.summary?.trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }
    final body = event.body?.trim();
    if (_isChatEvent(event) && body != null && body.isNotEmpty) {
      return body;
    }
    return null;
  }

  String? get _verboseBody {
    if (!showVerboseDetails || !event.isExpandable) {
      return null;
    }

    final summary = event.summary?.trim();
    final body = event.body?.trim();
    if (body == null || body.isEmpty || body == summary) {
      return null;
    }
    return body;
  }

  List<String> get _detailChips {
    final chips = <String>[];

    final timestampLabel = _timestampLabel;
    if (timestampLabel != null) {
      chips.add(timestampLabel);
    }

    if (!showVerboseDetails) {
      return chips;
    }

    final sourceId = event.sourceId?.trim();
    if (sourceId != null && sourceId.isNotEmpty && _isLocalThinkEvent(event)) {
      chips.add(sourceId);
    }

    final attempts = event.metadata['attempts'];
    final maxAttempts = event.metadata['maxAttempts'];
    if (attempts is int && maxAttempts is int) {
      chips.add('Attempt ${attempts.clamp(0, maxAttempts)}/$maxAttempts');
    }

    final dedupKey = _stringMetadata('dedupKey');
    if (dedupKey != null) {
      chips.add('Dedup: $dedupKey');
    }

    final notify = _stringMetadata('notify');
    if (notify != null) {
      chips.add('Notify: $notify');
    }

    final wakeGate = _stringMetadata('wakeGate');
    if (wakeGate != null) {
      chips.add('Wake gate: $wakeGate');
    }

    final parentTaskId = _stringMetadata('parentTaskId');
    if (parentTaskId != null) {
      chips.add('Parent: $parentTaskId');
    }

    final contextFrom = _stringMetadata('contextFrom');
    if (contextFrom != null) {
      chips.add('Context: $contextFrom');
    }

    final exitCode = event.metadata['exitCode'];
    if (exitCode is int) {
      chips.add('Exit: $exitCode');
    }

    return chips;
  }

  String? get _timestampLabel {
    final timestamp = event.timestamp;
    if (timestamp == null) {
      return null;
    }
    return DateFormat('MMM d, HH:mm').format(timestamp.toLocal());
  }

  bool get _isSilent => event.metadata['isSilent'] == true;

  String? _stringMetadata(String key) {
    final value = event.metadata[key];
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool _isLocalThinkEvent(MainChatTimelineEvent event) {
    return switch (event.type) {
      MainChatTimelineEventType.localThinkQueued ||
      MainChatTimelineEventType.localThinkRunning ||
      MainChatTimelineEventType.localThinkCompleted ||
      MainChatTimelineEventType.localThinkCancelled ||
      MainChatTimelineEventType.localThinkFailed ||
      MainChatTimelineEventType.localThinkSkipped =>
        true,
      _ => false,
    };
  }

  bool _isChatEvent(MainChatTimelineEvent event) {
    return switch (event.type) {
      MainChatTimelineEventType.chatUser ||
      MainChatTimelineEventType.chatAssistant ||
      MainChatTimelineEventType.chatSystem =>
        true,
      _ => false,
    };
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (segments.isEmpty) {
      return path;
    }
    final name = segments.last.trim();
    return name.isEmpty ? 'artifact' : name;
  }

  IconData _iconForEvent(MainChatTimelineEvent event) {
    if (_isSilent) {
      return Icons.pause_circle_outline;
    }
    return switch (event.type) {
      MainChatTimelineEventType.localThinkQueued => Icons.schedule,
      MainChatTimelineEventType.localThinkRunning => Icons.sync,
      MainChatTimelineEventType.localThinkCompleted =>
        Icons.check_circle_outline,
      MainChatTimelineEventType.localThinkCancelled => Icons.cancel_outlined,
      MainChatTimelineEventType.localThinkFailed => Icons.error_outline,
      MainChatTimelineEventType.localThinkSkipped => Icons.pause_circle_outline,
      MainChatTimelineEventType.chatUser => Icons.person_outline,
      MainChatTimelineEventType.chatAssistant => Icons.smart_toy_outlined,
      MainChatTimelineEventType.chatSystem => Icons.info_outline,
      MainChatTimelineEventType.toolStarted => Icons.play_circle_outline,
      MainChatTimelineEventType.toolFinished => Icons.task_alt,
      MainChatTimelineEventType.restartRecovered => Icons.restart_alt,
      MainChatTimelineEventType.artifactCreated => Icons.attach_file,
    };
  }

  Color _colorForEvent(MainChatTimelineEvent event, ColorScheme scheme) {
    if (_isSilent) {
      return scheme.outline;
    }
    return switch (event.type) {
      MainChatTimelineEventType.localThinkCancelled => scheme.outline,
      MainChatTimelineEventType.localThinkFailed => scheme.error,
      MainChatTimelineEventType.localThinkCompleted => scheme.primary,
      MainChatTimelineEventType.localThinkRunning => scheme.tertiary,
      MainChatTimelineEventType.localThinkQueued => scheme.secondary,
      MainChatTimelineEventType.localThinkSkipped => scheme.outline,
      MainChatTimelineEventType.chatUser => scheme.primary,
      MainChatTimelineEventType.chatAssistant => scheme.secondary,
      MainChatTimelineEventType.chatSystem => scheme.outline,
      MainChatTimelineEventType.toolStarted => scheme.tertiary,
      MainChatTimelineEventType.toolFinished => scheme.primary,
      MainChatTimelineEventType.restartRecovered => scheme.secondary,
      MainChatTimelineEventType.artifactCreated => scheme.secondary,
    };
  }

  String _labelForEvent(MainChatTimelineEvent event) {
    if (_isSilent) {
      return 'Silent';
    }
    return switch (event.type) {
      MainChatTimelineEventType.localThinkQueued => 'Queued',
      MainChatTimelineEventType.localThinkRunning => 'Running',
      MainChatTimelineEventType.localThinkCompleted => 'Completed',
      MainChatTimelineEventType.localThinkCancelled => 'Cancelled',
      MainChatTimelineEventType.localThinkFailed => 'Failed',
      MainChatTimelineEventType.localThinkSkipped => 'Skipped',
      MainChatTimelineEventType.chatUser => 'User',
      MainChatTimelineEventType.chatAssistant => 'Assistant',
      MainChatTimelineEventType.chatSystem => 'System',
      MainChatTimelineEventType.toolStarted => 'Tool started',
      MainChatTimelineEventType.toolFinished => 'Tool finished',
      MainChatTimelineEventType.restartRecovered => 'Recovered',
      MainChatTimelineEventType.artifactCreated => 'Artifact',
    };
  }
}

class _ArtifactChip extends StatelessWidget {
  const _ArtifactChip({
    required this.fileName,
    required this.color,
  });

  final String fileName;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.attach_file, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                'Artifact available',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Text(
          fileName,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
