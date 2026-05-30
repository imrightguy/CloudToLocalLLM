import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../models/chat_model.dart';
import '../../services/streaming_chat_service.dart';
import '../../services/connection_manager_service.dart';
import '../../components/message_bubble.dart';
import '../../components/message_input.dart' as msg_input;
import '../../components/glass_container.dart';
import '../../components/welcome_screen.dart';
import '../../components/animated_background.dart';

/// Main layout — clean chat interface, nothing else.
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
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final body = Stack(
      children: [
        const Positioned.fill(child: AnimatedBackground()),
        _ChatPane(
          isCompact: widget.isCompact,
          scrollController: widget.scrollController,
          onSendMessage: widget.onSendMessage,
        ),
      ],
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: body,
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureChannelExists();
    });
  }

  void _ensureChannelExists() {
    try {
      final chatService = context.read<StreamingChatService>();
      if (chatService.currentConversation == null) {
        chatService.createConversation();
      }
    } catch (_) {
      // StreamingChatService not registered on this platform (web).
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard against missing providers on platforms where services aren't registered
    try {
      return Consumer2<StreamingChatService, ConnectionManagerService>(
        builder: (context, chatService, connectionManager, child) {
          final conversation = chatService.currentConversation;
          final spacing = AppTheme.spacingOf(context);

          return Column(
            children: [
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
                  placeholder: 'Message Hermes...',
                ),
              ),
            ],
          );
        },
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
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
