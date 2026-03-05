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
import '../../widgets/chat/model_selector.dart';
import '../../widgets/chat/chat_control_bar.dart';
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
  bool _showThinking = true;
  bool _focusMode = false;
  bool _showCronSessions = true;
  String _currentSession = 'main';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProviderConfig();
      _ensureChannelExists();
    });
  }

  Future<void> _loadData() async {
    await _fetchProviderConfig();
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

  Future<void> _onModelChanged(String? model) async {
    if (model == null) return;

    try {
      final chatService = context.read<StreamingChatService>();
      final connectionManager = context.read<ConnectionManagerService>();

      // Update both services
      chatService.setSelectedModel(model);

      // Set active provider in OpenClaw Gateway
      final success = await connectionManager.setActiveProvider(model);
      if (!success) {
        debugPrint('[HomeLayout] Failed to set provider in OpenClaw Gateway');
      }
    } catch (e) {
      debugPrint('[HomeLayout] Error changing model: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreamingChatService, ConnectionManagerService>(
      builder: (context, chatService, connectionManager, child) {
        final conversation = chatService.currentConversation;
        final spacing = AppTheme.spacingOf(context);
        final availableModels = connectionManager.availableModels;
        final activeModel = connectionManager.activeProviderModelId ??
            chatService.selectedModel ??
            (availableModels.isNotEmpty ? availableModels.first : null);
        final isConnected = connectionManager.isConnected;

        final chatContent = Column(
          children: [
            if (!_focusMode)
              _ChatHeader(
                selectedModel: activeModel,
                availableModels: availableModels,
                onModelChanged: _onModelChanged,
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
                placeholder: 'Message OpenClaw...',
              ),
            ),
          ],
        );

        return Container(
          color: Colors.transparent,
          child: Column(
            children: [
              if (!_focusMode)
                ChatControlBar(
                  currentSession: _currentSession,
                  isConnected: isConnected,
                  onSessionChanged: (session) => setState(() => _currentSession = session),
                  onRefresh: _loadData,
                  onThinkingToggle: (value) => setState(() => _showThinking = value),
                  onFocusModeToggle: (value) => setState(() => _focusMode = value),
                  onCronSessionsToggle: (value) => setState(() => _showCronSessions = value),
                  showThinking: _showThinking,
                  focusMode: _focusMode,
                  showCronSessions: _showCronSessions,
                ),
              Expanded(child: chatContent),
            ],
          ),
        );
      },
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String? selectedModel;
  final List<String> availableModels;
  final Function(String?) onModelChanged;

  const _ChatHeader({
    required this.selectedModel,
    required this.availableModels,
    required this.onModelChanged,
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
      child: ModelSelector(
        selectedModel: selectedModel,
        availableModels: availableModels,
        onModelChanged: onModelChanged,
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
                  'OpenClaw',
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
