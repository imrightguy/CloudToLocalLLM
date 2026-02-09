import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/chat_model.dart';

class MessageContent extends StatelessWidget {
  final Message message;

  const MessageContent({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final hasReasoning = message.reasoning != null && message.reasoning!.isNotEmpty;
    final hasContent = message.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasReasoning) _buildReasoning(context),
        if (message.isStreaming && !hasContent && !hasReasoning)
          _buildTypingIndicator(context)
        else if (hasContent)
          SelectableText(
            message.content,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textColor, height: 1.5),
          ),
      ],
    );
  }

  Widget _buildReasoning(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Thinking',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            message.reasoning!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textColorLight,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
          ),
        ),
        SizedBox(width: AppTheme.spacingS),
        Text(
          'Thinking...',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textColorLight,
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}

