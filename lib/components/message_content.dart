import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import '../config/theme.dart';
import '../models/chat_model.dart';

class MessageContent extends StatelessWidget {
  final Message message;

  const MessageContent({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final hasReasoning =
        message.reasoning != null && message.reasoning!.isNotEmpty;
    final hasContent = message.content.isNotEmpty;
    final hasMarkdown = _hasMarkdown(message.content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasReasoning) _buildReasoning(context),
        if (hasContent)
          hasMarkdown
              ? _buildMarkdownContent(context, message.content)
              : SelectableText(
                  message.content,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.textColor, height: 1.5),
                ),
        if (message.isStreaming && !hasContent) _buildTypingIndicator(context),
      ],
    );
  }

  bool _hasMarkdown(String content) {
    return content.contains('```') ||
        content.contains('**') ||
        content.contains('#') ||
        content.contains('[') && content.contains('](') ||
        content.contains('* ') ||
        content.contains('![');
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
              const Icon(Icons.psychology_outlined,
                  size: 14, color: Colors.grey),
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

  Widget _buildMarkdownContent(BuildContext context, String content) {
    return MarkdownBody(
      data: content,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textColor,
              height: 1.5,
            ),
        h1: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
        h2: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
        h3: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textColor,
              fontWeight: FontWeight.bold,
            ),
        code: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.1),
              color: AppTheme.primaryColor,
            ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.secondaryColor.withValues(alpha: 0.3),
          ),
        ),
        blockquote: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textColorLight,
              fontStyle: FontStyle.italic,
            ),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.secondaryColor.withValues(alpha: 0.1),
          border: Border(
            left: BorderSide(
              color: AppTheme.secondaryColor,
              width: 3,
            ),
          ),
        ),
        listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textColor,
            ),
        tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
        tableBody: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textColor,
            ),
        tableBorder: TableBorder.all(
          color: AppTheme.secondaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      imageBuilder: (uri, title, alt) {
        return _buildImageWidget(uri.toString(), alt);
      },
    );
  }

  Widget _buildImageWidget(String url, String? alt) {
    if (url.startsWith('data:image')) {
      return _buildBase64Image(url, alt);
    } else {
      return _buildNetworkImage(url, alt);
    }
  }

  Widget _buildNetworkImage(String url, String? alt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.broken_image, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.grey),
                  ),
                  if (alt != null && alt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alt,
                      style: TextStyle(color: AppTheme.textColorLight),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBase64Image(String dataUrl, String? alt) {
    try {
      final base64String = dataUrl.split(',').last;
      final imageBytes = base64Decode(base64String);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            imageBytes,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.broken_image, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load base64 image',
                      style: TextStyle(color: Colors.grey),
                    ),
                    if (alt != null && alt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        alt,
                        style: TextStyle(color: AppTheme.textColorLight),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.dangerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Invalid base64 image',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
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
