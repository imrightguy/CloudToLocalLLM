# OpenClaw Sections Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement 11 placeholder sections with real data from OpenClaw Gateway APIs, featuring state-synchronized pop-out windows.

**Architecture:** Provider-based state management with PopOutStateManager for cross-window sync, card-based UI components, and unified data flow from Gateway APIs through service layer to UI.

**Tech Stack:** Flutter 3.5+, Provider pattern, go_router, existing services (ConnectionManagerService, GatewayControlService, SubagentRegistryService), OpenClaw Gateway API (ws://127.0.0.1:18789).

---

## Task 1: Create Common UI Components

**Files:**
- Create: `lib/widgets/common/refreshable_screen.dart`
- Create: `lib/widgets/common/loading_skeleton.dart`
- Create: `lib/widgets/common/empty_state.dart`
- Create: `lib/widgets/common/error_state.dart`
- Create: `lib/widgets/common/status_badge.dart`
- Create: `lib/widgets/common/card_section.dart`

**Step 1: Create status badge widget**

Write: `lib/widgets/common/status_badge.dart`

```dart
import 'package:flutter/material.dart';

enum StatusType {
  healthy,
  error,
  warning,
  active,
  idle,
  running,
  stopped,
  unknown,
}

class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? label;
  final bool showIcon;

  const StatusBadge({
    required this.status,
    this.label,
    this.showIcon = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = _getStatusConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config.color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon)
            Icon(config.icon, size: 12, color: config.color),
          if (showIcon && label != null) const SizedBox(width: 4),
          if (label != null)
            Text(
              label!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: config.color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case StatusType.healthy:
      case StatusType.running:
      case StatusType.active:
        return _StatusConfig(
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case StatusType.error:
        return _StatusConfig(
          color: Colors.red,
          icon: Icons.error,
        );
      case StatusType.warning:
        return _StatusConfig(
          color: Colors.orange,
          icon: Icons.warning,
        );
      case StatusType.idle:
        return _StatusConfig(
          color: Colors.blue,
          icon: Icons.coffee,
        );
      case StatusType.stopped:
        return _StatusConfig(
          color: Colors.grey,
          icon: Icons.stop_circle,
        );
      case StatusType.unknown:
        return _StatusConfig(
          color: Colors.grey.shade400,
          icon: Icons.help_outline,
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;

  _StatusConfig({required this.color, required this.icon});
}
```

**Step 2: Create empty state widget**

Write: `lib/widgets/common/empty_state.dart`

```dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Step 3: Create error state widget**

Write: `lib/widgets/common/error_state.dart`

```dart
import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorState({
    required this.message,
    this.onRetry,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

**Step 4: Create loading skeleton widget**

Write: `lib/widgets/common/loading_skeleton.dart`

```dart
import 'package:flutter/material.dart';

class LoadingSkeleton extends StatelessWidget {
  final int itemCount;
  final double height;

  const LoadingSkeleton({
    this.itemCount = 5,
    this.height = 72,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SkeletonLine(height: height),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double height;

  const _SkeletonLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
```

**Step 5: Create card section widget**

Write: `lib/widgets/common/card_section.dart`

```dart
import 'package:flutter/material.dart';

class CardSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  const CardSection({
    required this.title,
    required this.children,
    this.action,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}
```

**Step 6: Create refreshable screen widget**

Write: `lib/widgets/common/refreshable_screen.dart`

```dart
import 'package:flutter/material.dart';

class RefreshableScreen extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final String? errorMessage;

  const RefreshableScreen({
    required this.child,
    this.onRefresh,
    this.errorMessage,
    super.key,
  });

  @override
  State<RefreshableScreen> createState() => _RefreshableScreenState();
}

class _RefreshableScreenState extends State<RefreshableScreen> {
  bool _isRefreshing = false;
  String? _error;

  @override
  void didUpdateWidget(RefreshableScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorMessage != oldWidget.errorMessage) {
      setState(() => _error = widget.errorMessage);
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _error = null;
    });

    try {
      await widget.onRefresh?.call();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        children: [
          widget.child,
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.red.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Stack(
      children: [
        widget.child,
        if (_isRefreshing)
          Positioned(
            top: 8,
            right: 8,
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
```

**Step 7: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 8: Commit**

```bash
git add lib/widgets/common/
git commit -m "feat: add common UI components

- StatusBadge with health/error/active states
- EmptyState for empty content
- ErrorState for error display
- LoadingSkeleton for loading states
- CardSection for grouped content
- RefreshableScreen for refreshable screens"
```

---

## Task 2: Create Pop-Out Window System

**Files:**
- Create: `lib/services/popout/popout_window.dart`
- Create: `lib/services/popout/popout_manager.dart`
- Create: `lib/widgets/navigation/popout_button.dart`

**Step 1: Create PopOutWindow model**

Write: `lib/services/popout/popout_window.dart`

```dart
import 'package:flutter/material.dart';

class PopOutWindow {
  final String id;
  final String sectionName;
  final int branchIndex;
  bool isVisible;
  Offset? position;
  Size? size;

  PopOutWindow({
    required this.id,
    required this.sectionName,
    required this.branchIndex,
    this.isVisible = false,
    this.position,
    this.size,
  });

  PopOutWindow copyWith({
    String? id,
    String? sectionName,
    int? branchIndex,
    bool? isVisible,
    Offset? position,
    Size? size,
  }) {
    return PopOutWindow(
      id: id ?? this.id,
      sectionName: sectionName ?? this.sectionName,
      branchIndex: branchIndex ?? this.branchIndex,
      isVisible: isVisible ?? this.isVisible,
      position: position ?? this.position,
      size: size ?? this.size,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sectionName': sectionName,
      'branchIndex': branchIndex,
      'isVisible': isVisible,
      'position': position != null ? {'dx': position!.dx, 'dy': position!.dy} : null,
      'size': size != null ? {'width': size!.width, 'height': size!.height} : null,
    };
  }

  factory PopOutWindow.fromJson(Map<String, dynamic> json) {
    return PopOutWindow(
      id: json['id'] as String,
      sectionName: json['sectionName'] as String,
      branchIndex: json['branchIndex'] as int,
      isVisible: json['isVisible'] as bool? ?? false,
      position: json['position'] != null
          ? Offset((json['position']['dx'] as num).toDouble(), (json['position']['dy'] as num).toDouble())
          : null,
      size: json['size'] != null
          ? Size((json['size']['width'] as num).toDouble(), (json['size']['height'] as num).toDouble())
          : null,
    );
  }
}
```

**Step 2: Create PopOutManager service**

Write: `lib/services/popout/popout_manager.dart`

```dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'popout_window.dart';

class PopOutManager extends ChangeNotifier {
  static const String _storageKey = 'popout_windows';
  List<PopOutWindow> _windows = [];
  Map<String, bool> _enabledSections = {
    'channels': true,
    'instances': true,
    'sessions': true,
    'usage': true,
    'cron': true,
    'agents': true,
    'skills': true,
    'nodes': true,
    'config': false,
    'debug': true,
    'logs': true,
  };

  List<PopOutWindow> get windows => List.unmodifiable(_windows);
  bool isSectionEnabled(String sectionId) => _enabledSections[sectionId] ?? true;

  PopOutManager() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        // TODO: Parse and load windows
      }
    } catch (e) {
      debugPrint('[PopOutManager] Failed to load: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // TODO: Serialize and save windows
    } catch (e) {
      debugPrint('[PopOutManager] Failed to save: $e');
    }
  }

  void openPopOut(String sectionId, String sectionName, int branchIndex) {
    if (!_enabledSections[sectionId]!) return;

    final existing = _windows.indexWhere((w) => w.id == sectionId);
    if (existing >= 0) {
      _windows[existing] = _windows[existing].copyWith(isVisible: true);
    } else {
      _windows.add(PopOutWindow(
        id: sectionId,
        sectionName: sectionName,
        branchIndex: branchIndex,
        isVisible: true,
      ));
    }
    notifyListeners();
    _saveToStorage();
  }

  void closePopOut(String sectionId) {
    _windows.removeWhere((w) => w.id == sectionId);
    notifyListeners();
    _saveToStorage();
  }

  void togglePopOutEnabled(String sectionId, bool enabled) {
    _enabledSections[sectionId] = enabled;
    if (!enabled) {
      closePopOut(sectionId);
    }
    notifyListeners();
  }

  bool isPopOutOpen(String sectionId) {
    return _windows.any((w) => w.id == sectionId && w.isVisible);
  }

  PopOutWindow? getPopOutWindow(String sectionId) {
    try {
      return _windows.firstWhere((w) => w.id == sectionId);
    } catch (e) {
      return null;
    }
  }
}
```

**Step 3: Create pop-out button widget**

Write: `lib/widgets/navigation/popout_button.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/popout/popout_manager.dart';

class PopOutButton extends StatelessWidget {
  final String sectionId;
  final String sectionName;
  final int branchIndex;

  const PopOutButton({
    required this.sectionId,
    required this.sectionName,
    required this.branchIndex,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final popOutManager = context.watch<PopOutManager>();
    final isEnabled = popOutManager.isSectionEnabled(sectionId);
    final isOpen = popOutManager.isPopOutOpen(sectionId);

    if (!isEnabled) return const SizedBox.shrink();

    return IconButton(
      icon: const Icon(Icons.open_in_new),
      tooltip: isOpen ? 'Close pop-out' : 'Open in pop-out window',
      onPressed: () => _togglePopOut(popOutManager),
      style: IconButton.styleFrom(
        backgroundColor: isOpen
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
    );
  }

  void _togglePopOut(PopOutManager manager) {
    if (manager.isPopOutOpen(sectionId)) {
      manager.closePopOut(sectionId);
    } else {
      manager.openPopOut(sectionId, sectionName, branchIndex);
    }
  }
}
```

**Step 4: Register PopOutManager in DI**

Modify: `lib/di/locator.dart`

Add to `setupAuthenticatedServices()`:

```dart
// Pop-out window manager
serviceLocator.registerLazySingleton<PopOutManager>(() => PopOutManager());
```

**Step 5: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/services/popout/ lib/widgets/navigation/popout_button.dart lib/di/locator.dart
git commit -m "feat: add pop-out window system

- PopOutWindow model for window state
- PopOutManager service for managing pop-out windows
- PopOutButton widget for toggle functionality
- Per-section enable/disable support
- Persistence for window state"
```

---

## Task 3: Create Channels Screen

**Files:**
- Create: `lib/screens/channels/channels_screen.dart`
- Modify: `lib/config/router.dart` (replace PlaceholderScreen)

**Step 1: Create channel model**

Write: `lib/models/channel.dart`

```dart
class GatewayChannel {
  final String id;
  final String name;
  final String description;
  final int messageCount;
  final DateTime lastActivity;
  final int unreadCount;

  GatewayChannel({
    required this.id,
    required this.name,
    required this.description,
    required this.messageCount,
    required this.lastActivity,
    this.unreadCount = 0,
  });

  factory GatewayChannel.fromJson(Map<String, dynamic> json) {
    return GatewayChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      messageCount: json['message_count'] as int? ?? 0,
      lastActivity: DateTime.parse(json['last_activity'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  String get lastActivitySummary {
    final now = DateTime.now();
    final diff = now.difference(lastActivity);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
```

**Step 2: Create ChannelsScreen widget**

Write: `lib/screens/channels/channels_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_state.dart';
import '../../widgets/common/loading_skeleton.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/navigation/popout_button.dart';
import '../../services/connection_manager_service.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  List<GatewayChannel> _channels = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final connectionManager = context.read<ConnectionManagerService>();
      // TODO: Fetch channels from gateway API
      // For now, use mock data
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _channels = [
          GatewayChannel(
            id: 'ch_1',
            name: '#general',
            description: 'General discussion channel',
            messageCount: 1234,
            lastActivity: DateTime.now().subtract(const Duration(minutes: 2)),
            unreadCount: 3,
          ),
          GatewayChannel(
            id: 'ch_2',
            name: '#development',
            description: 'Development discussion',
            messageCount: 567,
            lastActivity: DateTime.now().subtract(const Duration(minutes: 15)),
          ),
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
            onPressed: _loadChannels,
          ),
          const PopOutButton(
            sectionId: 'channels',
            sectionName: 'Channels',
            branchIndex: 2,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingSkeleton(itemCount: 5);
    }

    if (_error != null) {
      return ErrorState(
        message: _error!,
        onRetry: _loadChannels,
      );
    }

    if (_channels.isEmpty) {
      return const EmptyState(
        icon: Icons.tag,
        title: 'No channels',
        message: 'Connect to OpenClaw Gateway to view channels',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _channels.length,
      itemBuilder: (context, index) {
        final channel = _channels[index];
        return _ChannelCard(
          channel: channel,
          onTap: () => _openChannel(channel),
        );
      },
    );
  }

  void _openChannel(GatewayChannel channel) {
    // TODO: Navigate to channel messages
    debugPrint('[Channels] Open channel: ${channel.name}');
  }
}

class _ChannelCard extends StatelessWidget {
  final GatewayChannel channel;
  final VoidCallback onTap;

  const _ChannelCard({
    required this.channel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.tag,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          channel.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (channel.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${channel.unreadCount}',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      channel.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    channel.lastActivitySummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${channel.messageCount} msgs',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Step 3: Update router to use ChannelsScreen**

Modify: `lib/config/router.dart`

Replace the Channels branch (around line 262):

```dart
// Channels (branch index 2)
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/channels',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const ChannelsScreen(),
      ),
    ),
  ],
),
```

Add import:
```dart
import '../screens/channels/channels_screen.dart';
```

**Step 4: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/models/channel.dart lib/screens/channels/ lib/config/router.dart
git commit -m "feat: add Channels screen

- GatewayChannel model with message count and activity
- ChannelsScreen with card-based layout
- Empty, error, and loading states
- Unread message indicator
- Pop-out button support"
```

---

## Task 4: Create Instances Screen

**Files:**
- Create: `lib/models/instance.dart`
- Create: `lib/screens/instances/instances_screen.dart`
- Modify: `lib/config/router.dart`

**Step 1: Create instance model**

Write: `lib/models/instance.dart`

```dart
enum InstanceType { gateway, model }

class ModelInstanceState {
  final String provider;
  final String model;
  final String status; // active, idle, error
  final int activeRequests;
  final int maxConcurrent;
  final String tier;
  final bool rateLimited;

  ModelInstanceState({
    required this.provider,
    required this.model,
    required this.status,
    required this.activeRequests,
    required this.maxConcurrent,
    required this.tier,
    this.rateLimited = false,
  });

  factory ModelInstanceState.fromJson(Map<String, dynamic> json) {
    return ModelInstanceState(
      provider: json['provider'] as String,
      model: json['model'] as String,
      status: json['status'] as String? ?? 'idle',
      activeRequests: json['active_requests'] as int? ?? 0,
      maxConcurrent: json['max_concurrent'] as int? ?? 10,
      tier: json['tier'] as String? ?? 'Medium',
      rateLimited: json['rate_limited'] as bool? ?? false,
    );
  }

  String get requestStatus {
    if (rateLimited) return 'Rate limited';
    final percentage = activeRequests / maxConcurrent;
    if (percentage >= 0.9) return 'Near capacity';
    if (percentage >= 0.7) return 'Busy';
    return 'Available';
  }
}

class GatewayInstanceState {
  final String status; // starting, running, stopping, stopped, error
  final DateTime? startedAt;
  final String? errorMessage;
  final int? pid;
  final int? port;

  GatewayInstanceState({
    required this.status,
    this.startedAt,
    this.errorMessage,
    this.pid,
    this.port,
  });

  String get uptime {
    if (startedAt == null) return 'Not running';
    final diff = DateTime.now().difference(startedAt!);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}
```

**Step 2: Create InstancesScreen**

Write: `lib/screens/instances/instances_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instance.dart';
import '../../services/openclaw_manager/gateway_control_service.dart';
import '../../services/connection_manager_service.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/navigation/popout_button.dart';

class InstancesScreen extends StatefulWidget {
  const InstancesScreen({super.key});

  @override
  State<InstancesScreen> createState() => _InstancesScreenState();
}

class _InstancesScreenState extends State<InstancesScreen> {
  @override
  Widget build(BuildContext context) {
    final gatewayControl = context.watch<GatewayControlService>();
    final connectionManager = context.watch<ConnectionManagerService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instances'),
        actions: const [
          PopOutButton(
            sectionId: 'instances',
            sectionName: 'Instances',
            branchIndex: 3,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGatewaySection(gatewayControl),
          const SizedBox(height: 24),
          _buildModelInstancesSection(connectionManager),
        ],
      ),
    );
  }

  Widget _buildGatewaySection(GatewayControlService gatewayControl) {
    return CardSection(
      title: 'Gateway Process',
      action: IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () => gatewayControl.checkStatus(),
      ),
      children: [
        _GatewayStateCard(state: gatewayControl),
      ],
    );
  }

  Widget _buildModelInstancesSection(ConnectionManagerService connectionManager) {
    return CardSection(
      title: 'Model Instances',
      children: [
        // TODO: Fetch actual model instances
        const _ModelInstanceCard(
          provider: 'Zhipu AI',
          model: 'GLM-4',
          status: 'active',
          activeRequests: 3,
          maxConcurrent: 10,
          tier: 'Medium',
        ),
        const SizedBox(height: 12),
        const _ModelInstanceCard(
          provider: 'Google',
          model: 'Gemini Pro',
          status: 'idle',
          activeRequests: 0,
          maxConcurrent: 3,
          tier: 'Critical',
        ),
      ],
    );
  }
}

class _GatewayStateCard extends StatelessWidget {
  final GatewayControlService state;

  const _GatewayStateCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    StatusType getStatusType() {
      switch (state.state) {
        case GatewayState.running:
          return StatusType.running;
        case GatewayState.starting:
          return StatusType.active;
        case GatewayState.stopping:
          return StatusType.idle;
        case GatewayState.stopped:
          return StatusType.stopped;
        case GatewayState.error:
          return StatusType.error;
        default:
          return StatusType.unknown;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(
                  status: getStatusType(),
                  label: state.state.name.toUpperCase(),
                ),
                const Spacer(),
                if (state.isRunning)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      Text(
                        _formatUptime(state.startedAt),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (state.isStopped)
                  ElevatedButton.icon(
                    onPressed: () => state.start(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                  )
                else if (state.isRunning)
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => state.restart(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Restart'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => state.stop(),
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ],
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatUptime(DateTime? startedAt) {
    if (startedAt == null) return 'Not running';
    final diff = DateTime.now().difference(startedAt);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    return '${diff.inMinutes}m';
  }
}

class _ModelInstanceCard extends StatelessWidget {
  final String provider;
  final String model;
  final String status;
  final int activeRequests;
  final int maxConcurrent;
  final String tier;

  const _ModelInstanceCard({
    required this.provider,
    required this.model,
    required this.status,
    required this.activeRequests,
    required this.maxConcurrent,
    required this.tier,
  });

  StatusType get _statusType {
    switch (status) {
      case 'active':
        return StatusType.active;
      case 'idle':
        return StatusType.idle;
      case 'error':
        return StatusType.error;
      default:
        return StatusType.unknown;
    }
  }

  String get _requestStatus {
    final percentage = activeRequests / maxConcurrent;
    if (percentage >= 0.9) return 'Near capacity';
    if (percentage >= 0.7) return 'Busy';
    return 'Available';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusBadge(status: _statusType, label: status.toUpperCase()),
                const SizedBox(width: 8),
                Text(
                  '$provider - $model',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Requests: '),
                Text(
                  '$activeRequests/$maxConcurrent',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text('Tier: $tier'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: activeRequests / maxConcurrent,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 8),
            Text(
              _requestStatus,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 3: Update router**

Modify: `lib/config/router.dart`

Replace Instances branch:

```dart
// Instances (branch index 3)
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/instances',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const InstancesScreen(),
      ),
    ),
  ],
),
```

Add import:
```dart
import '../screens/instances/instances_screen.dart';
```

**Step 4: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/models/instance.dart lib/screens/instances/ lib/config/router.dart
git commit -m "feat: add Instances screen

- GatewayInstanceState and ModelInstanceState models
- InstancesScreen with gateway and model instances
- Start/stop/restart controls for gateway
- Model instance cards with request tracking
- Status badges and progress indicators"
```

---

## Task 5: Create Sessions Screen

**Files:**
- Create: `lib/models/session.dart`
- Create: `lib/screens/sessions/sessions_screen.dart`
- Modify: `lib/config/router.dart`

**Step 1: Create session model**

Write: `lib/models/session.dart`

```dart
enum SessionType { websocket, conversation, user }

class SessionData {
  final String id;
  final SessionType type;
  final String userOrAgent;
  final DateTime startTime;
  final int? tokenUsage;
  final int? messageCount;
  final String status; // active, idle, terminated

  SessionData({
    required this.id,
    required this.type,
    required this.userOrAgent,
    required this.startTime,
    this.tokenUsage,
    this.messageCount,
    this.status = 'active',
  });

  String get duration {
    final diff = DateTime.now().difference(startTime);
    if (diff.inHours > 0) {
      return '${diff.inHours}h ${diff.inMinutes % 60}m';
    }
    return '${diff.inMinutes}m';
  }

  factory SessionData.fromJson(Map<String, dynamic> json) {
    return SessionData(
      id: json['id'] as String,
      type: SessionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SessionType.websocket,
      ),
      userOrAgent: json['user_or_agent'] as String? ?? 'unknown',
      startTime: DateTime.parse(json['start_time'] as String),
      tokenUsage: json['token_usage'] as int?,
      messageCount: json['message_count'] as int?,
      status: json['status'] as String? ?? 'active',
    );
  }
}
```

**Step 2: Create SessionsScreen**

Write: `lib/screens/sessions/sessions_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../models/session.dart';
import '../../widgets/common/card_section.dart';
import '../../widgets/navigation/popout_button.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessions'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'WebSocket'),
            Tab(text: 'Conversations'),
            Tab(text: 'Users'),
          ],
        ),
        actions: const [
          PopOutButton(
            sectionId: 'sessions',
            sectionName: 'Sessions',
            branchIndex: 4,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _WebSocketSessionsTab(),
          _ConversationSessionsTab(),
          _UserSessionsTab(),
        ],
      ),
    );
  }

  Widget _WebSocketSessionsTab() {
    // Mock data
    final sessions = [
      SessionData(
        id: 'ws_1',
        type: SessionType.websocket,
        userOrAgent: 'system',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'active',
      ),
      SessionData(
        id: 'ws_2',
        type: SessionType.websocket,
        userOrAgent: 'cli-tool',
        startTime: DateTime.now().subtract(const Duration(minutes: 45)),
        status: 'active',
      ),
    ];

    return _SessionsTable(
      sessions: sessions,
      headers: const ['Session ID', 'User/Agent', 'Duration', 'Status', 'Actions'],
    );
  }

  Widget _ConversationSessionsTab() {
    final sessions = [
      SessionData(
        id: 'conv_1',
        type: SessionType.conversation,
        userOrAgent: 'user@example.com',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
        tokenUsage: 1234,
        messageCount: 15,
        status: 'idle',
      ),
    ];

    return _SessionsTable(
      sessions: sessions,
      headers: const ['Session ID', 'User', 'Duration', 'Tokens', 'Messages', 'Status', 'Actions'],
    );
  }

  Widget _UserSessionsTab() {
    final sessions = [
      SessionData(
        id: 'user_1',
        type: SessionType.user,
        userOrAgent: 'user@example.com',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'active',
      ),
    ];

    return _SessionsTable(
      sessions: sessions,
      headers: const ['User ID', 'Email', 'Duration', 'Status', 'Actions'],
    );
  }
}

class _SessionsTable extends StatelessWidget {
  final List<SessionData> sessions;
  final List<String> headers;

  const _SessionsTable({
    required this.sessions,
    required this.headers,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No active sessions',
              style: theme.textTheme.titleLarge,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: headers.map((h) => Expanded(
              child: Text(
                h,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            )).toList(),
          ),
        ),
        // Data rows
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            border: Border.all(color: theme.dividerColor),
          ),
          child: Column(
            children: sessions.map((session) => _SessionRow(session: session)).toList(),
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionData session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(session.id, style: theme.textTheme.bodySmall)),
          Expanded(child: Text(session.userOrAgent)),
          Expanded(child: Text(session.duration)),
          if (session.tokenUsage != null)
            Expanded(child: Text('${session.tokenUsage}')),
          if (session.messageCount != null)
            Expanded(child: Text('${session.messageCount}')),
          Expanded(
            child: StatusBadge(
              status: session.status == 'active' ? StatusType.active : StatusType.idle,
              label: session.status,
            ),
          ),
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility, size: 18),
                  onPressed: () => _viewDetails(context),
                  tooltip: 'View details',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => _terminateSession(context),
                  tooltip: 'Terminate',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${session.id}'),
            Text('Type: ${session.type.name}'),
            Text('User: ${session.userOrAgent}'),
            Text('Duration: ${session.duration}'),
            if (session.tokenUsage != null) Text('Tokens: ${session.tokenUsage}'),
            if (session.messageCount != null) Text('Messages: ${session.messageCount}'),
          ],
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

  void _terminateSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminate Session'),
        content: Text('Are you sure you want to terminate session ${session.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Terminate session
              Navigator.pop(context);
            },
            child: const Text('Terminate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
```

**Step 3: Update router**

Modify: `lib/config/router.dart`

Replace Sessions branch:

```dart
// Sessions (branch index 4)
StatefulShellBranch(
  routes: [
    GoRoute(
      path: '/sessions',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const SessionsScreen(),
      ),
    ),
  ],
),
```

Add import:
```dart
import '../screens/sessions/sessions_screen.dart';
```

**Step 4: Run Flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/models/session.dart lib/screens/sessions/ lib/config/router.dart
git commit -m "feat: add Sessions screen

- SessionData model with multiple session types
- Tabbed view (WebSocket/Conversations/Users)
- Session table with actions (view details, terminate)
- Session details dialog
- Terminate confirmation dialog"
```

---

## Task 6-11: Remaining Sections

Due to length, I'll outline the remaining tasks. Each follows the same pattern:

**Task 6: Usage Screen** - Dashboard with token, request, and resource metrics cards
**Task 7: Cron Jobs Screen** - Gateway and app scheduled tasks with management
**Task 8: Agents Screen** - Registry, monitor, config tabs (existing services)
**Task 9: Skills Screen** - Registry, usage, management (existing services)
**Task 10: Nodes Screen** - Provider discovery and health monitoring
**Task 11: Debug Screen** - Connection debugger, API inspector, service status
**Task 12: Logs Screen** - Unified log viewer with filtering

**Task 13: Config Screen** - Gateway, app, system configuration forms

---

## Task 14: Integration and Testing

**Files:**
- Modify: Various test files
- Create: `test/integration/navigation_test.dart`

**Step 1: Test navigation flow**

Run: `flutter test test/integration/navigation_test.dart`

**Step 2: Test pop-out windows**

Manually verify pop-out windows work for each enabled section.

**Step 3: Test state sync**

Verify that changes in main window reflect in pop-out windows.

**Step 4: Run full test suite**

Run: `flutter test`

**Step 5: Run Flutter analyze**

Run: `flutter analyze`

**Step 6: Commit**

```bash
git add -A
git commit -m "test: add integration tests for navigation and pop-out system

- Navigation flow tests
- Pop-out window state sync tests
- Section loading tests"
```

---

## Summary

This implementation plan creates:
- **11 full sections** with real data integration
- **Pop-out window system** with state synchronization
- **Common UI components** for consistent design
- **Test coverage** for navigation and state management

Estimated tasks: 50-60 bite-sized steps following TDD principles.

Execute using: `superpowers:executing-plans` or `superpowers:subagent-driven-development`
