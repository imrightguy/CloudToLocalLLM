import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/streaming_chat_service.dart';
import '../../services/theme_provider.dart';
import '../../services/platform_detection_service.dart';
import '../../components/message_bubble.dart';
import '../../components/message_input.dart' as msg_input;
import '../../components/app_logo.dart';
import '../../components/tunnel_status_button.dart';
import '../../components/web_download_prompt.dart';
import '../../components/conversation_list.dart';
import '../../widgets/chat/model_selector.dart';
import '../../services/auth_service.dart';
import '../../services/web_download_prompt_service.dart';
import '../../services/connection_manager_service.dart';
import '../../services/google_workspace_service.dart';

/// Main layout for the chat interface, handling responsiveness and sidebar toggle.
class HomeLayout extends StatefulWidget {
  const HomeLayout({
    super.key,
    required this.isCompact,
    required this.isSidebarCollapsed,
    required this.onSidebarToggle,
    required this.scrollController,
    required this.onSendMessage,
  });

  final bool isCompact;
  final bool isSidebarCollapsed;
  final VoidCallback onSidebarToggle;
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
    if (widget.isCompact && !widget.isSidebarCollapsed) {
      widget.onSidebarToggle();
    }
    return;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final platformService = context.read<PlatformDetectionService>();
    final theme = Theme.of(context);
    final showSidebar = !widget.isSidebarCollapsed;

    // Apply keyboard shortcuts on desktop platforms
    final body = Stack(
      children: [
        Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: themeProvider.isDarkMode
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primaryColor,
                          theme.primaryColor.withValues(alpha: 0.8),
                        ],
                      )
                    : AppTheme.headerGradient,
              ),
              child: _HeaderBar(
                isCompact: widget.isCompact,
                isSidebarCollapsed: widget.isSidebarCollapsed,
                onSidebarToggle: widget.onSidebarToggle,
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: showSidebar ? (widget.isCompact ? 260 : 300) : 0,
                    child: showSidebar
                        ? const _SidebarPane()
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: _ChatPane(
                      isCompact: widget.isCompact,
                      scrollController: widget.scrollController,
                      onSendMessage: widget.onSendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (kIsWeb) const Positioned.fill(child: _WebDownloadOverlay()),
        if (kIsWeb) const TunnelStatusButton(),
      ],
    );

    // Wrap with keyboard shortcuts on desktop
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
      floatingActionButton: widget.isCompact && widget.isSidebarCollapsed
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

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.isCompact,
    required this.isSidebarCollapsed,
    required this.onSidebarToggle,
  });

  final bool isCompact;
  final bool isSidebarCollapsed;
  final VoidCallback onSidebarToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final spacing = AppTheme.spacingOf(context);
    final iconColor =
        themeProvider.isDarkMode ? theme.colorScheme.onPrimary : Colors.white;

    return Padding(
      padding: EdgeInsets.all(spacing.m),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCompact)
                IconButton(
                  onPressed: onSidebarToggle,
                  icon: Icon(
                    isSidebarCollapsed ? Icons.menu : Icons.close,
                    color: iconColor,
                  ),
                  // Ensure minimum touch target size on mobile
                  constraints: BoxConstraints(
                    minWidth: isCompact ? 44.0 : 32.0,
                    minHeight: isCompact ? 44.0 : 32.0,
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo.small(
                    backgroundColor: Colors.white,
                    textColor: Color(0xFF6e8efb),
                    borderColor: Color(0xFFa777e3),
                  ),
                  SizedBox(width: spacing.s),
                  Text(
                    AppConfig.appName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.smart_toy, color: Colors.white),
            tooltip: 'GUI Automation',
            onPressed: () => context.go('/gui-automation'),
          ),
          IconButton(
            icon: const Icon(Icons.dashboard, color: Colors.white),
            tooltip: 'Admin Dashboard',
            onPressed: () => context.go('/admin-center'),
          ),
          SizedBox(width: spacing.m),
          const _EmailStatusIndicator(),
          SizedBox(width: spacing.m),
          const _UserMenu(),
        ],
      ),
    );
  }
}

class _EmailStatusIndicator extends StatelessWidget {
  const _EmailStatusIndicator();

  @override
  Widget build(BuildContext context) {
    return Consumer<GoogleWorkspaceService>(
      builder: (context, workspaceService, child) {
        final isConnected = workspaceService.connectedAccounts.isNotEmpty;
        final isLoading = workspaceService.isLoading;

        if (isLoading) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          );
        }

        return IconButton(
          icon: Icon(
            isConnected ? Icons.workspace_premium : Icons.mail_outline,
            color: isConnected ? Colors.greenAccent : Colors.white70,
          ),
          tooltip: isConnected ? 'Check Workspace' : 'Connect Google Workspace',
          onPressed: () async {
            if (!isConnected) {
              await workspaceService.connectAccount();
            } else {
              final email = workspaceService.connectedAccounts.first;
              final messages = await workspaceService.getUnreadMessages(email);
              final events = await workspaceService.getTodayEvents(email);
              if (context.mounted) {
                _showWorkspacePopup(context, messages, events);
              }
            }
          },
        );
      },
    );
  }

  void _showWorkspacePopup(BuildContext context,
      List<Map<String, dynamic>> messages, List<Map<String, dynamic>> events) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Workspace'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Upcoming Events',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                if (events.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No events for today'))
                else
                  ...events.map((e) => ListTile(
                        title: Text(e['summary']),
                        subtitle: Text('${e['start']} - ${e['end']}'),
                        leading: const Icon(Icons.calendar_today, size: 20),
                      )),
                const SizedBox(height: 20),
                const Text('Unread Emails',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Divider(),
                if (messages.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No unread messages'))
                else
                  ...messages.map((m) => ListTile(
                        title: Text(m['subject'],
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${m['from']} • ${m['date']}'),
                        isThreeLine: true,
                        leading: const Icon(Icons.email, size: 20),
                      )),
              ],
            ),
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

class _UserMenu extends StatelessWidget {
  const _UserMenu();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final spacing = AppTheme.spacingOf(context);
        final user = authService.currentUser;
        return PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'login':
                if (context.mounted) {
                  context.go('/login');
                }
                break;
              case 'settings':
                if (context.mounted) {
                  context.go('/settings');
                }
                break;
              case 'logout':
                await authService.logout();
                if (context.mounted) {
                  context.go('/login');
                }
                break;
            }
          },
          itemBuilder: (context) => [
            if (!authService.isAuthenticated.value)
              PopupMenuItem(
                value: 'login',
                child: Row(
                  children: [
                    const Icon(Icons.cloud_queue, size: 18),
                    SizedBox(width: spacing.s),
                    const Text('Connect Cloud Relay'),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(Icons.settings, size: 18),
                  SizedBox(width: spacing.s),
                  const Text('Settings'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            if (authService.isAuthenticated.value)
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout, size: 18),
                    SizedBox(width: spacing.s),
                    const Text('Sign Out'),
                  ],
                ),
              ),
          ],
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          ),
          color: AppTheme.backgroundCard,
          shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 8),
          child: Container(
            padding: EdgeInsets.all(spacing.xs),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: authService.isAuthenticated.value
                    ? Colors.green.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: authService.isAuthenticated.value
                  ? AppTheme.primaryColor
                  : Colors.grey[700],
              child: authService.isAuthenticated.value
                  ? Text(
                      user?.initials ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Icon(Icons.cloud_off, size: 16, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarPane extends StatelessWidget {
  const _SidebarPane();

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        return Column(
          children: [
            Expanded(
              child: ConversationList(
                conversations: chatService.conversations,
                selectedConversation: chatService.currentConversation,
                onConversationSelected: (conversationId) {
                  final conversation = chatService.conversations.firstWhere(
                    (c) => c.id == conversationId,
                  );
                  chatService.selectConversation(conversation);
                },
                onConversationDeleted: (conversationId) {
                  final conversation = chatService.conversations.firstWhere(
                    (c) => c.id == conversationId,
                  );
                  chatService.deleteConversation(conversation);
                },
                onConversationRenamed: (conversationId, newTitle) {
                  final conversation = chatService.conversations.firstWhere(
                    (c) => c.id == conversationId,
                  );
                  chatService.updateConversationTitle(conversation, newTitle);
                },
                onNewConversation: () => chatService.createConversation(),
                isCollapsed: false,
              ),
            ),
          ],
        );
      },
    );
  }
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
  @override
  void initState() {
    super.initState();
    // Fetch provider config on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProviderConfig();
    });
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
    final theme = Theme.of(context);

    return Consumer2<StreamingChatService, ConnectionManagerService>(
      builder: (context, chatService, connectionManager, child) {
        final conversation = chatService.currentConversation;
        final spacing = AppTheme.spacingOf(context);
        final availableModels = connectionManager.availableModels;
        final activeModel = connectionManager.activeProviderModelId ??
            chatService.selectedModel ??
            (availableModels.isNotEmpty ? availableModels.first : null);

        if (conversation == null) {
          return const _EmptyConversationState();
        }

        return Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              _ChatHeader(
                selectedModel: activeModel,
                availableModels: availableModels,
                onModelChanged: _onModelChanged,
              ),
              Expanded(
                child: _MessageList(
                  conversation: conversation,
                  controller: widget.scrollController,
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  bottom: widget.isCompact ? spacing.m : spacing.l,
                  left: spacing.m,
                  right: spacing.m,
                ),
                color: theme.scaffoldBackgroundColor,
                child: msg_input.MessageInput(
                  onSendMessage: (message) =>
                      widget.onSendMessage(chatService, message),
                  isLoading: chatService.isLoading,
                  placeholder: 'Type your message...',
                ),
              ),
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

class _EmptyConversationState extends StatelessWidget {
  const _EmptyConversationState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);
    final textColor = theme.colorScheme.onSurface;
    final textColorLight = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: textColorLight,
                ),
                SizedBox(height: spacing.l),
                Text(
                  'Welcome to CloudToLocalLLM',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.m),
                Text(
                  'Start a new conversation to begin chatting with your local LLM',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColorLight,
                      ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: spacing.xl),
                Consumer<StreamingChatService>(
                  builder: (context, chatService, child) {
                    return ElevatedButton.icon(
                      onPressed: () => chatService.createConversation(),
                      icon: const Icon(Icons.add),
                      label: const Text('Start New Conversation'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.l,
                          vertical: spacing.m,
                        ),
                        // Ensure minimum touch target size
                        minimumSize: const Size(44, 44),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
