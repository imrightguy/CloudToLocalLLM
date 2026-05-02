import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/communication_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'visit_form_screen.dart';

class ConversationDetailScreen extends StatefulWidget {
  const ConversationDetailScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
    required this.contactInitials,
  });

  final String contactId;
  final String contactName;
  final String contactPhone;
  final String contactInitials;

  @override
  State<ConversationDetailScreen> createState() =>
      _ConversationDetailScreenState();
}

class _ConversationDetailScreenState extends State<ConversationDetailScreen> {
  List<CommunicationItem> _messages = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items =
          await CommunicationService.instance.getConversationLogs(
        contactId: widget.contactId,
      );
      setState(() {
        _messages = items.reversed.toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();

    try {
      await CommunicationService.instance.createCommunication({
        'contactId': widget.contactId,
        'type': 'sms',
        'direction': 'outbound',
        'status': 'sent',
        'body': text,
      });
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  String _formatMessageTime(DateTime dt) {
    return DateFormat('HH:mm', 'fr').format(dt);
  }

  String _formatDateSeparator(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dt.year, dt.month, dt.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (messageDate == today) return "Aujourd'hui";
    if (messageDate == yesterday) return 'Hier';
    return DateFormat('d MMMM yyyy', 'fr').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contactName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              widget.contactPhone,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            tooltip: 'Planifier une visite',
            icon: const Icon(Icons.event_available_outlined, color: AppColors.textSecondary),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => VisitFormScreen(
                    initialLeadId: widget.contactId,
                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Appel — bientôt disponible')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchMessages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageItem(_messages[index], index);
                        },
                      ),
                    ),
                    _buildReplyInputBar(),
                  ],
                ),
    );
  }

  Widget _buildMessageItem(CommunicationItem message, int index) {
    final bool showDateSeparator = index == 0 ||
        (_messages.length > index + 1 &&
            !_isSameDay(message.createdAt, _messages[index + 1].createdAt));

    final List<Widget> children = [];

    if (showDateSeparator) {
      children.add(_buildDateSeparator(message.createdAt));
    }

    if (message.direction == 'outbound') {
      children.add(_buildSentBubble(message));
    } else {
      children.add(_buildReceivedBubble(message));
    }

    return Column(
      children: children,
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime dt) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDateSeparator(dt),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSentBubble(CommunicationItem message) {
    if (message.status == 'failed') {
      return _buildFailedBubble(message);
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: const TextStyle(fontSize: 14, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.createdAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                _buildBubbleStatusIcon(message.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedBubble(CommunicationItem message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: AppColors.errorLight),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.body,
              style: const TextStyle(fontSize: 14, color: AppColors.error),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.error_outline,
                    size: 14, color: AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedBubble(CommunicationItem message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 16, right: 48, top: 4, bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            AppSpacing.elevationCard,
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return const Icon(Icons.check, size: 14, color: Color(0x80FFFFFF));
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Color(0x80FFFFFF));
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: AppColors.primary);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildReplyInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _replyController,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle:
                      TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: IconButton(
              icon:
                  const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
