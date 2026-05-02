import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/streaming_chat_service.dart';
import '../../services/platform_detection_service.dart';
import '../../components/message_bubble.dart';
import '../../components/message_input.dart' as msg_input;
import '../../components/app_logo.dart';
import '../../components/tunnel_status_button.dart';
import '../../components/web_download_prompt.dart';
import '../../services/web_download_prompt_service.dart';
import '../../services/connection_manager_service.dart';

import '../../components/glass_container.dart';
import '../../components/welcome_screen.dart';
import '../../components/animated_background.dart';

/// Main layout for the chat interface - single channel direct communication.
class HomeLayout extends StatefulWidget {
  const HomeLayout({
    super.key,
    required this.isCompact,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
      onSendMessage;

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  final Map<LogicalKeySet, Intent> _shortcuts = {
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
        const _NewConversationIntent(),
    LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
        const _FocusSearchIntent(),
    LogicalKeySet(LogicalKeyboardKey.escape): const _CloseSidebarIntent(),
  };

  final Map<Type, Action<Intent>> _actions = {};

  @override
  void initState() {
    super.initState();
    _actions[_NewConversationIntent] = CallbackAction<_NewConversationIntent>(
      onInvoke: (_) => _handleNewConversation(),
    );
    _actions[_FocusSearchIntent] = CallbackAction<_FocusSearchIntent>(
      onInvoke: (_) => _handleFocusSearch(),
    );
    _actions[_CloseSidebarIntent] = CallbackAction<_CloseSidebarIntent>(
      onInvoke: (_) => _handleCloseSidebar(),
    );
  }

  void _handleNewConversation() {
    final chatService = context.read<StreamingChatService>();
    chatService.createConversation();
    return;
  }

  void _handleFocusSearch() {
    // Focus search/input - implementation depends on MessageInput widget
    return;
  }

  void _handleCloseSidebar() {
    return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platformService = context.read<PlatformDetectionService>();

    final body = Row(
      children: [
        // Old sidebar removed - OpenClawNavigationShell now provides WebUI sidebar
        Expanded(
          child: Stack(
            children: [
              const Positioned.fill(child: AnimatedBackground()),
              Column(
                children: [
                  // Old header removed - OpenClawNavigationShell now provides top banner
                  Expanded(
                    child: _ChatPane(
                      isCompact: widget.isCompact,
                      scrollController: widget.scrollController,
                      onSendMessage: widget.onSendMessage,
                    ),
                  ),
                ],
              ),
              if (kIsWeb) const Positioned.fill(child: _WebDownloadOverlay()),
              if (kIsWeb) const TunnelStatusButton(),
            ],
          ),
        ),
      ],
    );

    // Wrap with keyboard shortcuts on desktop
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: widget.isCompact
          ? Drawer(
              child: _Sidebar(
                onNavigate: (route) {
                  Navigator.pop(context);
                  context.go(route);
                },
              ),
            )
          : null,
      body: platformService.isDesktop
          ? Shortcuts(
              shortcuts: _shortcuts,
              child: Actions(
                actions: _actions,
                child: Focus(
                  autofocus: true,
                  child: body,
                ),
              ),
            )
          : body,
      floatingActionButton: widget.isCompact
          ? _NewConversationButton(
              minTouchTarget: widget.isCompact ? 44.0 : 32.0,
            )
          : null,
    );
  }
}

// Intent classes for keyboard shortcuts
class _NewConversationIntent extends Intent {
  const _NewConversationIntent();
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _CloseSidebarIntent extends Intent {
  const _CloseSidebarIntent();
}

class _ChatPane extends StatefulWidget {
  const _ChatPane({
    required this.isCompact,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final ScrollController scrollController;
  final void Function(StreamingChatService service, String message)
      onSendMessage;

  @override
  State<_ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<_ChatPane> {
  final bool _focusMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _ensureChannelExists();
    });
  }

  Future<void> _loadData() async {
    await _fetchProviderConfig();
    if (!mounted) return;
    final connectionManager = context.read<ConnectionManagerService>();
    await connectionManager.testConnection();
  }

  void _ensureChannelExists() {
    final chatService = context.read<StreamingChatService>();
    if (chatService.currentConversation == null) {
      chatService.createConversation();
    }
  }

  Future<void> _fetchProviderConfig() async {
    try {
      final connectionManager = context.read<ConnectionManagerService>();
      await connectionManager.fetchProviderConfig();
    } catch (e) {
      debugPrint('[HomeLayout] Error fetching provider config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreamingChatService, ConnectionManagerService>(
      builder: (context, chatService, connectionManager, child) {
        final conversation = chatService.currentConversation;
        final spacing = AppTheme.spacingOf(context);

        final chatContent = Column(
          children: [
            if (!_focusMode)
              _RuntimeChannelHeader(
                connectionManager: connectionManager,
                onRefresh: _loadData,
                onConfigure: () => context.go('/config'),
              ),
            Expanded(
              child: conversation != null && conversation.messages.isNotEmpty
                  ? _MessageList(
                      conversation: conversation,
                      controller: widget.scrollController,
                    )
                  : WelcomeScreen(
                      onNewChat: () => chatService.createConversation(),
                      onAction: (message) =>
                          widget.onSendMessage(chatService, message),
                    ),
            ),
            GlassContainer(
              margin: EdgeInsets.only(
                bottom: widget.isCompact ? spacing.m : spacing.l,
                left: spacing.m,
                right: spacing.m,
              ),
              borderRadius: 24,
              blur: 20,
              child: msg_input.MessageInput(
                onSendMessage: (message) =>
                    widget.onSendMessage(chatService, message),
                isLoading: chatService.isLoading,
                placeholder: 'Message the active runtime...',
              ),
            ),
          ],
        );

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              Expanded(child: chatContent),
            ],
          ),
        );
      },
    );
  }
}

class _RuntimeChannelHeader extends StatelessWidget {
  const _RuntimeChannelHeader({
    required this.connectionManager,
    required this.onRefresh,
    required this.onConfigure,
  });

  final ConnectionManagerService connectionManager;
  final VoidCallback onRefresh;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final status = connectionManager.getGatewayStatus();
    final runtimeLabel = status['backendLabel']?.toString() ??
        _backendLabel(connectionManager.currentBackend);
    final identity = connectionManager.activeRuntimeClient?.identity;
    final capabilityManifest = connectionManager.activeRuntimeCapabilities;
    final runtimeUrl = identity?.baseUrl;
    final models = _runtimeModelCount(connectionManager);
    final connected = connectionManager.isConnected;
    final statusLabel = connectionManager.currentBackend == null
        ? 'Setup needed'
        : connected
            ? 'Connected'
            : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hub_outlined,
            color:
                connected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Secure Runtime Channel',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  runtimeUrl == null
                      ? runtimeLabel
                      : '$runtimeLabel - $runtimeUrl',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  icon: connected ? Icons.check_circle : Icons.error_outline,
                  label: statusLabel,
                  color: connected ? Colors.green : colorScheme.error,
                ),
                _StatusChip(
                  icon: Icons.desktop_windows_outlined,
                  label: capabilityManifest?.desktopActionRequests == true
                      ? 'Desktop approved'
                      : 'Desktop gated',
                  color: colorScheme.secondary,
                ),
                _StatusChip(
                  icon: Icons.memory_outlined,
                  label: models == 1
                      ? '1 runtime model'
                      : '$models runtime models',
                  color: colorScheme.tertiary,
                ),
                IconButton(
                  tooltip: 'Refresh runtime',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
                OutlinedButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Manage'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _backendLabel(BackendType? backend) {
    return switch (backend) {
      BackendType.hermes => 'Hermes Agent',
      BackendType.openclaw => 'OpenClaw Gateway',
      null => 'No agent runtime selected',
    };
  }

  static int _runtimeModelCount(ConnectionManagerService connectionManager) {
    final capabilityModels =
        connectionManager.activeRuntimeCapabilities?.models.length ?? 0;
    final configuredModels = connectionManager.availableModels.length;
    return capabilityModels > configuredModels
        ? capabilityModels
        : configuredModels;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.conversation, required this.controller});

  final Conversation conversation;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final spacing = AppTheme.spacingOf(context);
    final messages = conversation.messages.reversed.toList();

    return ListView.builder(
      controller: controller,
      reverse: true,
      padding: EdgeInsets.symmetric(vertical: spacing.m),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(
          key: ValueKey(message.id),
          message: message,
          showAvatar: true,
          onRetry: message.hasError
              ? () {
                  final chatService = context.read<StreamingChatService>();
                  _retryMessage(chatService, message);
                }
              : null,
        );
      },
    );
  }

  static void _retryMessage(
    StreamingChatService chatService,
    Message errorMessage,
  ) {
    final conversation = chatService.currentConversation;
    if (conversation == null) return;

    String? lastUserMessage;
    final messages = conversation.messages;

    for (int i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      if (msg.id == errorMessage.id) {
        for (int j = i - 1; j >= 0; j--) {
          if (messages[j].role == MessageRole.user) {
            lastUserMessage = messages[j].content;
            break;
          }
        }
        break;
      }
    }

    if (lastUserMessage != null && lastUserMessage.isNotEmpty) {
      chatService.sendMessage(lastUserMessage);
    }
  }
}

class _WebDownloadOverlay extends StatelessWidget {
  const _WebDownloadOverlay();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Consumer<WebDownloadPromptService>(
        builder: (context, webDownloadPrompt, child) {
          if (!webDownloadPrompt.shouldShowPrompt) {
            return const SizedBox.shrink();
          }

          return WebDownloadPrompt(
            isFirstTimeUser: webDownloadPrompt.isFirstTimeUser,
            onDismiss: () async {
              await webDownloadPrompt.markPromptSeen();
              await webDownloadPrompt.hidePrompt();
            },
          );
        },
      ),
    );
  }
}

class _NewConversationButton extends StatelessWidget {
  const _NewConversationButton({this.minTouchTarget = 44.0});

  final double minTouchTarget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        return SizedBox(
          width: minTouchTarget,
          height: minTouchTarget,
          child: FloatingActionButton(
            onPressed: () => chatService.createConversation(),
            backgroundColor: theme.primaryColor,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.onNavigate});

  final void Function(String route) onNavigate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard.withValues(alpha: 0.8),
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(spacing.l),
            child: Row(
              children: [
                const AppLogo.small(),
                SizedBox(width: spacing.s),
                Text(
                  'CloudToLocalLLM',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chat',
            isSelected: location == '/',
            onTap: () => onNavigate('/'),
          ),
          _SidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isSelected: location == '/dashboard',
            onTap: () => onNavigate('/dashboard'),
          ),
          _SidebarItem(
            icon: Icons.smart_toy_outlined,
            label: 'Agent Monitor',
            isSelected: location == '/agents',
            onTap: () => onNavigate('/agents'),
          ),
          const Spacer(),
          const Divider(height: 1),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: location.startsWith('/settings'),
            onTap: () => onNavigate('/settings'),
          ),
          SizedBox(height: spacing.m),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.m,
        vertical: spacing.xs,
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        selected: isSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
        selectedTileColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        leading: Icon(
          icon,
          color: isSelected ? AppTheme.primaryColor : Colors.grey[400],
          size: 20,
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isSelected ? AppTheme.primaryColor : Colors.grey[300],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
