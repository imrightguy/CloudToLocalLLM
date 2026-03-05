library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/channel.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/refreshable_screen.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';

/// Screen displaying gateway communication channels
///
/// Shows a list of all active channels in the OpenClaw Gateway,
/// including message counts, unread indicators, and last activity timestamps.
class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  /// Loading state indicator
  bool _isLoading = true;

  /// Error message if data loading fails
  String? _errorMessage;

  /// List of channels to display
  List<GatewayChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  /// Load channels data
  ///
  /// TODO: Replace with actual API integration
  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(milliseconds: 500));

      // TODO: Replace with actual API call
      // final channels = await apiService.getChannels();

      // Mock data for now
      final channels = _getMockChannels();

      if (mounted) {
        setState(() {
          _channels = channels;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load channels: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Get mock channels data for testing
  ///
  /// TODO: Remove this method when API integration is complete
  List<GatewayChannel> _getMockChannels() {
    final now = DateTime.now();
    return [
      GatewayChannel(
        id: 'ch-001',
        name: 'main',
        description: 'Primary communication channel',
        messageCount: 1247,
        lastActivity: now.subtract(const Duration(minutes: 2)),
        unreadCount: 3,
      ),
      GatewayChannel(
        id: 'ch-002',
        name: 'agent-events',
        description: 'Agent lifecycle and event notifications',
        messageCount: 856,
        lastActivity: now.subtract(const Duration(hours: 1)),
        unreadCount: 0,
      ),
      GatewayChannel(
        id: 'ch-003',
        name: 'system-monitor',
        description: 'System health and metrics',
        messageCount: 2341,
        lastActivity: now.subtract(const Duration(minutes: 15)),
        unreadCount: 12,
      ),
      GatewayChannel(
        id: 'ch-004',
        name: 'debug-output',
        description: 'Debug and development messages',
        messageCount: 432,
        lastActivity: now.subtract(const Duration(days: 1)),
        unreadCount: 0,
      ),
      GatewayChannel(
        id: 'ch-005',
        name: 'notifications',
        description: 'User notifications and alerts',
        messageCount: 89,
        lastActivity: now.subtract(const Duration(hours: 3)),
        unreadCount: 1,
      ),
    ];
  }

  /// Format timestamp for display
  String _formatLastActivity(DateTime? timestamp) {
    if (timestamp == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(timestamp);
    }
  }

  /// Get icon based on channel name/type
  IconData _getChannelIcon(String channelName) {
    final name = channelName.toLowerCase();

    if (name.contains('main') || name.contains('primary')) {
      return Icons.chat_bubble;
    } else if (name.contains('agent') || name.contains('event')) {
      return Icons.smart_toy;
    } else if (name.contains('system') || name.contains('monitor')) {
      return Icons.monitor_heart;
    } else if (name.contains('debug') || name.contains('log')) {
      return Icons.bug_report;
    } else if (name.contains('notification') || name.contains('alert')) {
      return Icons.notifications;
    } else {
      return Icons.tag;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh channels',
            onPressed: _isLoading ? null : _loadChannels,
          ),
          const PopOutButton(
            sectionName: 'channels',
            branchIndex: 2,
          ),
        ],
      ),
      body: RefreshableScreen(
        onRefresh: _loadChannels,
        errorMessage: _errorMessage,
        child: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const LoadingSkeleton(
        itemCount: 5,
        height: 96,
      );
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: _errorMessage!,
        onRetry: _loadChannels,
      );
    }

    if (_channels.isEmpty) {
      return const EmptyState(
        icon: Icons.tag,
        title: 'No Channels',
        message: 'No communication channels are currently available.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        return _ChannelCard(
          channel: channel,
          formatLastActivity: _formatLastActivity,
          getChannelIcon: _getChannelIcon,
        );
      },
    );
  }
}

/// Card widget for displaying a single channel
class _ChannelCard extends StatelessWidget {
  final GatewayChannel channel;
  final String Function(DateTime?) formatLastActivity;
  final IconData Function(String) getChannelIcon;

  const _ChannelCard({
    required this.channel,
    required this.formatLastActivity,
    required this.getChannelIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = getChannelIcon(channel.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to channel detail view
          debugPrint('Tapped channel: ${channel.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Channel icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Channel info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and unread badge
                    Row(
                      children: [
                        Text(
                          channel.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (channel.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                            ),
                            child: Text(
                              channel.unreadCount > 99
                                  ? '99+'
                                  : '${channel.unreadCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onError,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Description
                    if (channel.description != null) ...[
                      Text(
                        channel.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Activity time and message count
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatLastActivity(channel.lastActivity),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.message,
                          size: 14,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${channel.messageCount} messages',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              const SizedBox(width: 8),
              StatusBadge(
                status: channel.unreadCount > 0
                    ? StatusType.active
                    : StatusType.idle,
                label: channel.unreadCount > 0 ? 'New' : 'Read',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
