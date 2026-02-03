import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/conversation.dart';

/// A sidebar component showing the list of conversations
class ConversationList extends StatefulWidget {
  final List<Conversation> conversations;
  final Conversation? selectedConversation;
  final Function(String) onConversationSelected;
  final Function(String) onConversationDeleted;
  final Function(String, String) onConversationRenamed;
  final VoidCallback onNewConversation;
  final bool isCollapsed;

  const ConversationList({
    super.key,
    required this.conversations,
    this.selectedConversation,
    required this.onConversationSelected,
    required this.onConversationDeleted,
    required this.onConversationRenamed,
    required this.onNewConversation,
    this.isCollapsed = false,
  });

  @override
  State<ConversationList> createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  String? _editingConversationId;
  final TextEditingController _editController = TextEditingController();

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return _buildCollapsedView();
    }

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          right: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildConversationList()),
        ],
      ),
    );
  }

  Widget _buildCollapsedView() {
    return Container(
      width: 60,
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          right: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // New conversation button
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingS),
            child: IconButton(
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.add),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
              ),
              tooltip: 'New Conversation',
            ),
          ),

          // Conversation indicators
          Expanded(
            child: ListView.builder(
              itemCount: widget.conversations.length,
              itemBuilder: (context, index) {
                final conversation = widget.conversations[index];
                final isSelected =
                    widget.selectedConversation?.id == conversation.id;

                return Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingS,
                    vertical: AppTheme.spacingXS,
                  ),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppTheme.borderRadiusS,
                      ),
                      border: isSelected
                          ? Border.all(color: AppTheme.primaryColor, width: 2)
                          : null,
                    ),
                    child: IconButton(
                      onPressed: () =>
                          widget.onConversationSelected(conversation.id),
                      icon: const Icon(Icons.chat_bubble_outline),
                      iconSize: 20,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textColorLight,
                      tooltip: conversation.title,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.secondaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Conversations',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          IconButton(
            onPressed: () => context.go('/agent-status'),
            icon: const Text('🦞', style: TextStyle(fontSize: 18)),
            iconSize: 20,
            color: AppTheme.primaryColor,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
            ),
            tooltip: 'Agent Status',
          ),
          IconButton(
            onPressed: widget.onNewConversation,
            icon: const Icon(Icons.add),
            iconSize: 20,
            color: AppTheme.primaryColor,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
              ),
            ),
            tooltip: 'New Conversation',
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (widget.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppTheme.textColorLight,
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No conversations yet',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textColorLight),
            ),
            SizedBox(height: AppTheme.spacingS),
            TextButton.icon(
              onPressed: widget.onNewConversation,
              icon: const Icon(Icons.add),
              label: const Text('Start chatting'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.conversations.length,
      itemBuilder: (context, index) {
        final conversation = widget.conversations[index];
        return _buildConversationItem(conversation);
      },
    );
  }

  Widget _buildConversationItem(Conversation conversation) {
    final isSelected = widget.selectedConversation?.id == conversation.id;
    final isEditing = _editingConversationId == conversation.id;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        border: isSelected
            ? Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                width: 1,
              )
            : null,
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        leading: Icon(
          Icons.chat_bubble_outline,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textColorLight,
          size: 20,
        ),
        title: isEditing
            ? _buildEditingTitle(conversation)
            : _buildTitle(conversation),
        subtitle: _buildSubtitle(conversation),
        trailing: _buildTrailing(conversation),
        onTap: isEditing
            ? null
            : () => widget.onConversationSelected(conversation.id),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
        ),
      ),
    );
  }

  Widget _buildTitle(Conversation conversation) {
    return Text(
      conversation.title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w500,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildEditingTitle(Conversation conversation) {
    return TextField(
      controller: _editController,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.w500,
          ),
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        isDense: true,
      ),
      onSubmitted: (value) => _finishEditing(conversation, value),
      onEditingComplete: () =>
          _finishEditing(conversation, _editController.text),
      autofocus: true,
    );
  }

  Widget _buildSubtitle(Conversation conversation) {
    return Text(
      conversation.preview,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTheme.textColorLight),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing(Conversation conversation) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(value, conversation),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              SizedBox(width: 8),
              Text('Rename'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 16),
              SizedBox(width: 8),
              Text('Delete'),
            ],
          ),
        ),
      ],
      child: Icon(Icons.more_vert, color: AppTheme.textColorLight, size: 16),
    );
  }

  void _handleMenuAction(String action, Conversation conversation) {
    switch (action) {
      case 'rename':
        _startEditing(conversation);
        break;
      case 'delete':
        _showDeleteConfirmation(conversation);
        break;
    }
  }

  void _startEditing(Conversation conversation) {
    setState(() {
      _editingConversationId = conversation.id;
      _editController.text = conversation.title;
    });
  }

  void _finishEditing(Conversation conversation, String newTitle) {
    if (newTitle.trim().isNotEmpty && newTitle.trim() != conversation.title) {
      widget.onConversationRenamed(conversation.id, newTitle.trim());
    }
    setState(() {
      _editingConversationId = null;
      _editController.clear();
    });
  }

  void _showDeleteConfirmation(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text(
          'Are you sure you want to delete "${conversation.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onConversationDeleted(conversation.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
