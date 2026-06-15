import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/communication_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/error_state.dart';
import 'visit_form_screen.dart';

class SmsConversationScreen extends StatefulWidget {
  const SmsConversationScreen({
    super.key,
    required this.contactId,
    required this.contactName,
    required this.contactPhone,
  });

  final String contactId;
  final String contactName;
  final String contactPhone;

  @override
  State<SmsConversationScreen> createState() =>
      _SmsConversationScreenState();
}

class _SmsConversationScreenState extends State<SmsConversationScreen> {
  List<SmsMessage> _messages = [];
  bool _isLoading = true;
  Object? _errorMessage;
  bool _isSending = false;
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const _quickReplies = [
    QuickReply(label: 'Confirmer', message: 'Confirmé. Merci !', icon: Icons.check_circle_outline),
    QuickReply(label: 'Annuler', message: 'Annulé. Désolé pour le dérangement.', icon: Icons.cancel_outlined),
    QuickReply(label: 'Reporter', message: 'Je souhaite reporter. Quand êtes-vous disponible ?', icon: Icons.schedule_outlined),
    QuickReply(label: 'Appeler', message: 'Je vous appelle dans quelques instants.', icon: Icons.phone_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items =
          await CommunicationService.instance.getSmsConversation(
        contactId: widget.contactId,
      );
      setState(() {
        _messages = items.reversed.toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _errorMessage = e;
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String body) async {
    if (body.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      await CommunicationService.instance.sendSms(
        contactId: widget.contactId,
        body: body.trim(),
      );
      _fetchMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();
    await _sendMessage(text);
  }

  Future<void> _sendQuickReply(QuickReply reply) async {
    await _sendMessage(reply.message);
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? _buildErrorState()
              : Column(
                  children: [
                    Expanded(child: _buildMessageList()),
                    if (!_isSending) _buildQuickReplies(),
                    _buildReplyInputBar(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return ErrorState(error: _errorMessage!, onRetry: _fetchMessages);
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sms_outlined, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Aucun message',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            SizedBox(height: 8),
            Text(
              'Envoyez un message pour commencer la conversation.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildMessageItem(_messages[index], index);
      },
    );
  }

  Widget _buildMessageItem(SmsMessage message, int index) {
    final showDateSeparator = index == 0 ||
        (_messages.length > index + 1 &&
            !_isSameDay(message.createdAt, _messages[index + 1].createdAt));

    return Column(
      children: [
        if (showDateSeparator) _buildDateSeparator(message.createdAt),
        message.isFailed
            ? _buildFailedBubble(message)
            : message.isOutbound
                ? _buildSentBubble(message)
                : _buildReceivedBubble(message),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime dt) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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

  Widget _buildSentBubble(SmsMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                _buildDeliveryStatusIcon(message.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailedBubble(SmsMessage message) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 48, right: 16, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
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
            if (message.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                message.errorMessage!,
                style: const TextStyle(fontSize: 11, color: AppColors.error),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(message.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.error_outline, size: 14, color: AppColors.error),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedBubble(SmsMessage message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(left: 16, right: 48, top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [AppSpacing.elevationCard],
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

  Widget _buildDeliveryStatusIcon(SmsDeliveryStatus status) {
    switch (status) {
      case SmsDeliveryStatus.queued:
        return const Icon(Icons.schedule, size: 14, color: Color(0x80FFFFFF));
      case SmsDeliveryStatus.sent:
        return const Icon(Icons.check, size: 14, color: Color(0x80FFFFFF));
      case SmsDeliveryStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Color(0x80FFFFFF));
      case SmsDeliveryStatus.read:
        return const Icon(Icons.done_all, size: 14, color: AppColors.primaryLight);
      case SmsDeliveryStatus.failed:
        return const Icon(Icons.error_outline, size: 14, color: AppColors.error);
    }
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickReplies.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: reply.icon != null
                    ? Icon(reply.icon, size: 16, color: AppColors.primary)
                    : null,
                label: Text(reply.label),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.primarySurface,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: _isSending ? null : () => _sendQuickReply(reply),
              ),
            );
          }).toList(),
        ),
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _replyController,
                decoration: const InputDecoration(
                  hintText: 'Écrire un message...',
                  hintStyle: TextStyle(fontSize: 14, color: AppColors.textMuted),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendReply(),
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
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendReply,
                  ),
          ),
        ],
      ),
    );
  }
}
