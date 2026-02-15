import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';

/// Renders the main chat message input area.
class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isLoading;
  final String? placeholder;
  final int maxLines;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.isLoading = false,
    this.placeholder,
    this.maxLines = 4,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isEmpty = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final isEmpty = _controller.text.trim().isEmpty;
    if (isEmpty != _isEmpty) {
      setState(() {
        _isEmpty = isEmpty;
      });
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isLoading) {
      widget.onSendMessage(text);
      _controller.clear();
      
      // Re-focus the text field after sending
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: AppTheme.backgroundMain,
        border: Border(
          top: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: widget.maxLines * 24.0 +
                      32, // Approximate line height + padding
                ),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundCard,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : AppTheme.secondaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _sendMessage();
                    }
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    enabled: !widget.isLoading,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textColor,
                          height: 1.5,
                        ),
                    decoration: InputDecoration(
                      hintText: widget.placeholder ?? 'Type your message...',
                      hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textColorLight,
                          ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(AppTheme.spacingM),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    onChanged: (_) => _onTextChanged(),
                  ),
                ),
              ),
            ),

            SizedBox(width: AppTheme.spacingS),

            // Send button
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final canSend = !_isEmpty && !widget.isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48,
      height: 48,
      child: Material(
        color: canSend
            ? AppTheme.primaryColor
            : AppTheme.textColorLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        child: InkWell(
          onTap: canSend ? _sendMessage : null,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
              boxShadow: canSend
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    )
                  : Icon(
                      Icons.send,
                      color: canSend ? Colors.white : AppTheme.textColorLight,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating action button for starting new conversations
class NewConversationFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isVisible;

  const NewConversationFAB({
    super.key,
    required this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: const Text('New Chat'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusM),
        ),
      ),
    );
  }
}

/// A model selector dropdown for the chat interface
class ModelSelector extends StatelessWidget {
  final List<String> models;
  final String? selectedModel;
  final Function(String?) onModelChanged;
  final bool isLoading;

  const ModelSelector({
    super.key,
    required this.models,
    this.selectedModel,
    required this.onModelChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (models.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingS,
        ),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_outlined,
              color: AppTheme.warningColor,
              size: 16,
            ),
            SizedBox(width: AppTheme.spacingS),
            Text(
              'No models available',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.warningColor),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedModel,
          hint: Text(
            'Select model',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
          ),
          items: models.map((model) {
            return DropdownMenuItem(
              value: model,
              child: Row(
                children: [
                  Icon(Icons.smart_toy, color: AppTheme.primaryColor, size: 16),
                  SizedBox(width: AppTheme.spacingS),
                  Flexible(
                    child: Text(
                      model,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textColor,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: isLoading ? null : onModelChanged,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textColor),
          dropdownColor: AppTheme.backgroundCard,
          icon: Icon(
            Icons.arrow_drop_down,
            color: AppTheme.textColorLight,
            size: 20,
          ),
        ),
      ),
    );
  }
}
