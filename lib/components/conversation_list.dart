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
  final TextEditingController _searchController = TextEditingController();
  List<Conversation> _filteredConversations = [];
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _editController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _filteredConversations = widget.conversations;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      final query = _searchController.text.toLowerCase();
      if (query.isEmpty) {
        _filteredConversations = widget.conversations;
      } else {
        _filteredConversations = widget.conversations.where((conv) {
          // Search in title
          if (conv.title.toLowerCase().contains(query)) return true;
          // Search in messages
          return conv.messages
              .any((m) => m.content.toLowerCase().contains(query));
        }).toList();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchExpanded = !_isSearchExpanded;
      if (!_isSearchExpanded) {
        _searchController.clear();
        _filteredConversations = widget.conversations;
      }
    });
  }

  Future<void> _showExportDialog() async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Conversations'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'json'),
            child: Row(
              children: const [
                Icon(Icons.description, color: Colors.blue),
                SizedBox(width: 8),
                Text('Export as JSON'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'csv'),
            child: Row(
              children: const [
                Icon(Icons.table_view, color: Colors.green),
                SizedBox(width: 8),
                Text('Export as CSV'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'none'),
            child: Row(
              children: const [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text('Cancel'),
              ],
            ),
          ),
        ],
      ),
    );

    if (action == null || action == 'none') return;

    // Future enhancement: Implement actual export to file
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Export to $action not implemented yet'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showImportDialog() async {
    // Future enhancement: Implement import from file
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Import from file not implemented yet'),
        duration: Duration(seconds: 2),
      ),
    );
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

          // Export button
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingS),
            child: IconButton(
              onPressed: _showExportDialog,
              icon: const Icon(Icons.file_download),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
              ),
              tooltip: 'Export Conversations',
            ),
          ),

          // Import button
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingS),
            child: IconButton(
              onPressed: _showImportDialog,
              icon: const Icon(Icons.file_upload),
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                foregroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                ),
              ),
              tooltip: 'Import Conversations',
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
      child: Column(
        children: [
          Row(
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
                onPressed: _isSearchExpanded ? _toggleSearch : _toggleSearch,
                icon: Icon(_isSearchExpanded ? Icons.search_off : Icons.search),
                iconSize: 20,
                color: AppTheme.primaryColor,
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                ),
                tooltip: _isSearchExpanded ? 'Close Search' : 'Search',
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
          if (_isSearchExpanded) ...[
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search conversations...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filteredConversations = widget.conversations;
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusS),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (_) => _onSearchChanged(),
              ),
            ),
            if (_filteredConversations.length !=
                widget.conversations.length) ...[
              const SizedBox(height: AppTheme.spacingXS),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppTheme.spacingS),
                child: Text(
                  '${_filteredConversations.length} of ${widget.conversations.length} conversations',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textColorLight,
                      ),
                ),
              ),
            ],
          ],
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

    if (_filteredConversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: AppTheme.textColorLight,
            ),
            SizedBox(height: AppTheme.spacingM),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textColorLight,
                  ),
            ),
            if (_searchController.text.isNotEmpty) ...[
              SizedBox(height: AppTheme.spacingS),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _filteredConversations = widget.conversations;
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear search'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredConversations.length,
      itemBuilder: (context, index) {
        final conversation = _filteredConversations[index];
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
