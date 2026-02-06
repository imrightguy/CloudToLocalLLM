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
import '../../components/message_input.dart';
import '../../components/app_logo.dart';
import '../../components/tunnel_status_button.dart';
import '../../components/web_download_prompt.dart';
import '../../components/conversation_list.dart';
import '../../services/auth_service.dart';
import '../../services/connection_manager_service.dart';
import '../../services/web_download_prompt_service.dart';

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
                    child: Stack(
                      children: [
                        _ChatPane(
                          isCompact: widget.isCompact,
                          scrollController: widget.scrollController,
                          onSendMessage: widget.onSendMessage,
                        ),
                        // Small persistent Zoidbot in corner of chat
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Consumer<StreamingChatService>(
                            builder: (context, chatService, child) {
                              if (chatService.currentConversation == null) return const SizedBox.shrink();
                              return const Opacity(
                                opacity: 0.5,
                                child: Text('🦞', style: TextStyle(fontSize: 24)),
                              );
                            },
                          ),
                        ),
                      ],
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
                  const Text('🦞', style: TextStyle(fontSize: 24)),
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
          const _ModelSelector(),
          SizedBox(width: spacing.m),
          const _UserMenu(),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector();

  @override
  Widget build(BuildContext context) {
    return Consumer2<StreamingChatService, ConnectionManagerService>(
      builder: (context, chatService, connectionManager, child) {
        final spacing = AppTheme.spacingOf(context);
        final models = connectionManager.availableModels;
        return Container(
          width: 200,
          padding: EdgeInsets.symmetric(horizontal: spacing.s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: chatService.selectedModel,
              hint: Text(
                'Select Model',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                overflow: TextOverflow.ellipsis,
              ),
              items: models.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (model) {
                if (model != null) {
                  chatService.setSelectedModel(model);
                }
              },
              dropdownColor: Colors.white,
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.white.withValues(alpha: 0.8),
              ),
              isExpanded: true,
            ),
          ),
        );
      },
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
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: Text(
                user?.initials ?? '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        return Column(
          children: [
            // Home button to go back to Zoidbot screen
            Padding(
              padding: EdgeInsets.all(spacing.s),
              child: ListTile(
                leading: const Text('🦞', style: TextStyle(fontSize: 20)),
                title: const Text('Zoidbot Home', style: TextStyle(fontWeight: FontWeight.bold)),
                selected: chatService.currentConversation == null,
                onTap: () => chatService.selectConversationById(null),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.s),
              child: ListTile(
                leading: const Icon(Icons.web, size: 20),
                title: const Text('Agent Browser', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => context.push('/browser'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing.s),
              child: ListTile(
                leading: const Icon(Icons.hub, size: 20),
                title: const Text('System Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => context.push('/system'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const Divider(),
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

class _ChatPane extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<StreamingChatService>(
      builder: (context, chatService, child) {
        final conversation = chatService.currentConversation;
        final spacing = AppTheme.spacingOf(context);

        if (conversation == null) {
          return const _EmptyConversationState();
        }

        return Container(
          color: theme.scaffoldBackgroundColor,
          child: Column(
            children: [
              Expanded(
                child: _MessageList(
                  conversation: conversation,
                  controller: scrollController,
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  bottom: isCompact ? spacing.m : spacing.l,
                  left: spacing.m,
                  right: spacing.m,
                ),
                color: theme.scaffoldBackgroundColor,
                child: MessageInput(
                  onSendMessage: (message) =>
                      onSendMessage(chatService, message),
                  isLoading: chatService.isLoading,
                  placeholder: chatService.selectedModel == null
                      ? 'Please select a model first...'
                      : 'Type your message...',
                ),
              ),
            ],
          ),
        );
      },
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
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.symmetric(vertical: spacing.m),
      itemCount: conversation.messages.length,
      itemBuilder: (context, index) {
        if (index >= conversation.messages.length) {
          return const SizedBox.shrink();
        }
        final message = conversation.messages[index];
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
    final authService = context.watch<AuthService>();
    final assistantName = authService.assistantName;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(spacing.l),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Expressive Agent Avatar (Zoidbot)
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.primaryColor.withValues(alpha: 0.3),
                        width: 6,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🦞',
                        style: TextStyle(fontSize: 80),
                      ),
                    ),
                  ),
                  SizedBox(height: spacing.xl),
                  Text(
                    '$assistantName is Ready!',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.m),
                  Text(
                    'How can I help you today?',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColorLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing.xl),
                  Wrap(
                    spacing: spacing.m,
                    runSpacing: spacing.m,
                    alignment: WrapAlignment.center,
                    children: [
                      _QuickActionCard(
                        icon: Icons.chat_bubble_outline,
                        label: 'Start Chatting',
                        onTap: () {
                          final chatService = Provider.of<StreamingChatService>(context, listen: false);
                          chatService.createConversation();
                        },
                        color: theme.primaryColor,
                      ),
                      if (authService.isAuthenticated.value) ...[
                        _QuickActionCard(
                          icon: Icons.dashboard_outlined,
                          label: 'Agent Dashboard',
                          onTap: () => context.go('/dashboard'),
                          color: Colors.blue,
                        ),
                      ],
                      if (!authService.isAuthenticated.value) ...[
                        _QuickActionCard(
                          icon: Icons.cloud_upload_outlined,
                          label: 'Connect Cloud',
                          onTap: () => context.go('/login'),
                          color: Colors.orange,
                        ),
                      ],
                      _QuickActionCard(
                        icon: Icons.web_outlined,
                        label: 'Agent Browser',
                        onTap: () => context.push('/browser'),
                        color: Colors.purple,
                      ),
                      _QuickActionCard(
                        icon: Icons.hub_outlined,
                        label: 'System Hub',
                        onTap: () => context.push('/system'),
                        color: Colors.teal,
                      ),
                      _QuickActionCard(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => context.go('/settings'),
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = AppTheme.spacingOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 160,
        padding: EdgeInsets.all(spacing.m),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: spacing.s),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
