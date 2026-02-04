import 'package:flutter/material.dart';

import 'package:cloudtolocalllm/models/agent_event.dart';

/// Real-time event stream showing all agent events
class EventStreamScreen extends StatefulWidget {
  final List<AgentEvent> events;

  const EventStreamScreen({super.key, required this.events});

  @override
  State<EventStreamScreen> createState() => _EventStreamScreenState();
}

class _EventStreamScreenState extends State<EventStreamScreen> {
  String _filterType = 'all';
  String _severityFilter = 'all';

  List<AgentEvent> get _filteredEvents {
    var filtered = widget.events;

    if (_filterType != 'all') {
      filtered = filtered.where((e) => e.eventType == _filterType).toList();
    }

    if (_severityFilter != 'all') {
      filtered = filtered.where((e) {
        final severity = e.eventData['severity'] as String?;
        return severity == _severityFilter;
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Filter bar
        _buildFilterBar(theme),
        const Divider(height: 1),
        // Event stream
        Expanded(
          child: _filteredEvents.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = _filteredEvents[index];
                    return _EventCard(event: event);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      child: Column(
        children: [
          // Event type filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: _filterType == 'all',
                  onSelected: (value) {
                    setState(() => _filterType = value);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Messages',
                  value: 'message_received',
                  selected: _filterType == 'message_received',
                  onSelected: (value) {
                    setState(() => _filterType = value);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Tools',
                  value: 'tool_start',
                  selected: _filterType == 'tool_start',
                  onSelected: (value) {
                    setState(() => _filterType = value);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Errors',
                  value: 'error',
                  selected: _filterType == 'error',
                  onSelected: (value) {
                    setState(() => _filterType = value);
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Status',
                  value: 'status_change',
                  selected: _filterType == 'status_change',
                  onSelected: (value) {
                    setState(() => _filterType = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Severity filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Severity: ', style: TextStyle(fontWeight: FontWeight.bold)),
                _FilterChip(
                  label: 'All',
                  value: 'all',
                  selected: _severityFilter == 'all',
                  onSelected: (value) {
                    setState(() => _severityFilter = value);
                  },
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Info',
                  value: 'info',
                  selected: _severityFilter == 'info',
                  onSelected: (value) {
                    setState(() => _severityFilter = value);
                  },
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Warning',
                  value: 'warning',
                  selected: _severityFilter == 'warning',
                  onSelected: (value) {
                    setState(() => _severityFilter = value;
                  },
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Error',
                  value: 'error',
                  selected: _severityFilter == 'error',
                  onSelected: (value) {
                    setState(() => _severityFilter = value);
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No events to display',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Events will appear here as agents send them',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final AgentEvent event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severity = event.eventData['severity'] as String? ?? 'info';

    return Card(
      child: InkWell(
        onTap: () => _showEventDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Event icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getEventIcon(event.eventType),
                  color: _getSeverityColor(severity),
                ),
              ),
              const SizedBox(width: 12),
              // Event details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventType.replaceAll('_', ' ').toUpperCase(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(event.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    if (event.eventData.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatEventData(event.eventData),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Severity badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getSeverityColor(severity),
                    width: 1,
                  ),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: TextStyle(
                    color: _getSeverityColor(severity),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'error':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
      default:
        return Colors.blue;
    }
  }

  IconData _getEventIcon(String eventType) {
    switch (eventType) {
      case 'message_received':
      case 'message_sent':
        return Icons.message;
      case 'message_thinking':
        return Icons.psychology;
      case 'tool_start':
        return Icons.play_arrow;
      case 'tool_end':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      case 'status_change':
        return Icons.swap_horiz;
      case 'agent_spawn':
        return Icons.add_circle;
      case 'agent_terminate':
        return Icons.remove_circle;
      case 'reply':
        return Icons.reply;
      default:
        return Icons.info;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  String _formatEventData(Map<String, dynamic> data) {
    if (data.isEmpty) return 'No data';
    return data.entries
        .map((e) => '${e.key}: ${_truncateValue(e.value.toString())}')
        .join(', ');
  }

  String _truncateValue(String value) {
    if (value.length > 50) {
      return '${value.substring(0, 47)}...';
    }
    return value;
  }

  void _showEventDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.eventType.replaceAll('_', ' ').toUpperCase()),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('Timestamp', event.timestamp.toIso8601String()),
              _DetailRow('Agent ID', event.agentId),
              if (event.correlationId != null)
                _DetailRow('Correlation ID', event.correlationId!),
              const Divider(),
              const Text(
                'Event Data:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...event.eventData.entries.map((entry) =>
                _DetailRow(
                  entry.key,
                  entry.value.toString(),
                )
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.blue;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (selected) => onSelected(value),
      selectedColor: chipColor.withOpacity(0.2),
      checkmarkColor: chipColor,
      backgroundColor: chipColor.withOpacity(0.1),
      side: BorderSide(
        color: selected ? chipColor : chipColor.withOpacity(0.3),
      ),
    );
  }
}
