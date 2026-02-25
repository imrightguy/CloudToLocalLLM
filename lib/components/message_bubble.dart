import 'package:flutter/material.dart';
import '../config/theme_extensions.dart';
import '../models/chat_model.dart';
import 'message_actions.dart';
import 'message_content.dart';
import 'package:flutter/services.dart';

/// A bubble-styled widget for displaying a single chat message.
class MessageBubble extends StatefulWidget {
  final Message message;
  final bool showAvatar;
  final VoidCallback? onRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.onRetry,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final colors = Theme.of(context).extension<AppColorsTheme>()!;
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser && widget.showAvatar) _buildAvatar(colors),
                Flexible(
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getBubbleColor(colors),
                          borderRadius: _getBorderRadius(isUser),
                          border: _getBubbleBorder(colors),
                          boxShadow: [
                            if (isUser)
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: _buildMessageContent(theme),
                      ),
                      // Stable action area to prevent layout shift
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4, left: 12, right: 12),
                        child: SizedBox(
                          height: 32, // Fixed height for action area
                          child: Row(
                            mainAxisAlignment: isUser
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: (_isHovered || widget.message.hasError)
                                    ? 1.0
                                    : 0.0,
                                child: MessageActions(
                                  message: widget.message,
                                  onCopy: () => _copyToClipboard(context),
                                  onRetry: widget.onRetry,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUser && widget.showAvatar) _buildAvatar(colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AppColorsTheme colors) {
    return Container(
      margin: const EdgeInsets.only(top: 4, left: 8, right: 8),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: colors.backgroundCard,
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.secondary.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          widget.message.isUser
              ? Icons.person_outline
              : Icons.smart_toy_outlined,
          size: 20,
          color: colors.primary,
        ),
      ),
    );
  }

  Color _getBubbleColor(AppColorsTheme colors) {
    if (widget.message.hasError) {
      return colors.danger.withValues(alpha: 0.1);
    }
    return widget.message.isUser
        ? colors.primary.withValues(alpha: 0.15)
        : colors.backgroundCard.withValues(alpha: 0.8);
  }

  Border? _getBubbleBorder(AppColorsTheme colors) {
    if (widget.message.hasError) {
      return Border.all(
        color: colors.danger.withValues(alpha: 0.3),
        width: 1.5,
      );
    }
    return Border.all(
      color: widget.message.isUser
          ? colors.primary.withValues(alpha: 0.3)
          : colors.secondary.withValues(alpha: 0.2),
      width: 1,
    );
  }

  BorderRadius _getBorderRadius(bool isUser) {
    const radius = Radius.circular(20);
    return BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: isUser ? radius : Radius.zero,
      bottomRight: isUser ? Radius.zero : radius,
    );
  }

  Widget _buildMessageContent(ThemeData theme) {
    return MessageContent(message: widget.message);
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
