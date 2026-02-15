import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/chat_model.dart';

class MessageActions extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCopy;
  final VoidCallback? onRetry;

  const MessageActions({
    super.key,
    required this.message,
    required this.onCopy,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.copy,
          tooltip: 'Copy message',
          onPressed: onCopy,
        ),
        if (message.hasError && onRetry != null)
          _buildActionButton(
            icon: Icons.refresh,
            tooltip: 'Retry',
            onPressed: onRetry!,
          ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: AppTheme.spacingS),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        iconSize: 16,
        color: AppTheme.textColorLight,
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
          ),
          padding: EdgeInsets.all(AppTheme.spacingXS),
          minimumSize: const Size(28, 28),
        ),
      ),
    );
  }
}
