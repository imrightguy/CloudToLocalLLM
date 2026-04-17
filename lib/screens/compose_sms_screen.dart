import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/communication_service.dart';
import '../services/lead_service.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';

class ComposeSmsScreen extends StatefulWidget {
  const ComposeSmsScreen({super.key});

  @override
  State<ComposeSmsScreen> createState() => _ComposeSmsScreenState();
}

class _ComposeSmsScreenState extends State<ComposeSmsScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isScheduled = false;
  DateTime? _scheduledAt;
  String? _selectedContactId;
  String? _selectedContactName;
  bool _isSending = false;

  List<LeadItem> _contacts = [];
  bool _contactsLoading = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    setState(() {});
  }

  int get _charCount => _messageController.text.length;

  Future<void> _loadContacts() async {
    setState(() => _contactsLoading = true);
    try {
      final result = await LeadService.instance.getLeads();
      setState(() {
        _contacts = result.items;
        _contactsLoading = false;
      });
    } catch (_) {
      setState(() => _contactsLoading = false);
    }
  }

  void _showContactSelector() {
    _loadContacts();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _ContactPickerSheet(
              contacts: _contacts,
              isLoading: _contactsLoading,
              scrollController: scrollController,
              onContactSelected: (lead) {
                Navigator.pop(context);
                setState(() {
                  _selectedContactId = lead.id;
                  _selectedContactName = lead.fullName;
                });
              },
            );
          },
        );
      },
    );
  }

  void _showTemplateSelector() {
    final templates = [
      const _SmsTemplate(id: 'visit_reminder', name: 'Rappel de visite',
          body: 'Bonjour, ceci est un rappel pour votre visite prévue.'),
      const _SmsTemplate(id: 'lease_ready', name: 'Bail prêt',
          body: 'Bonjour, votre bail est prêt pour signature.'),
      const _SmsTemplate(id: 'payment_reminder', name: 'Rappel de paiement',
          body: 'Bonjour, ceci est un rappel concernant votre paiement de loyer.'),
      const _SmsTemplate(id: 'maintenance_update', name: 'Mise à jour maintenance',
          body: 'Bonjour, nous vous informons de la progression des travaux.'),
      const _SmsTemplate(id: 'generic', name: 'Message générique',
          body: 'Bonjour, nous vous contactons concernant votre dossier.'),
    ];

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Choisir un modèle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Divider(height: 1),
              ...templates.map((t) {
                return ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.textSecondary),
                  title: Text(t.name),
                  subtitle: Text(
                    t.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _messageController.text = t.body;
                    });
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _toggleSchedule(bool value) {
    if (value) {
      _showDatePicker();
    } else {
      setState(() {
        _isScheduled = false;
        _scheduledAt = null;
      });
    }
  }

  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _isScheduled = true;
    });
  }

  Future<void> _sendOrSchedule() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez écrire un message')),
      );
      return;
    }
    if (_selectedContactId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un contact')),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final request = SmsScheduleRequest(
        contactId: _selectedContactId!,
        message: message,
        scheduledAt: _isScheduled ? _scheduledAt : null,
      );

      await CommunicationService.instance.scheduleSms(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isScheduled
                ? 'SMS planifié avec succès'
                : 'SMS envoyé avec succès'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Nouveau message', leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _showContactSelector,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 20, color: AppColors.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedContactName ?? 'Choisir un contact',
                        style: TextStyle(
                          fontSize: 14,
                          color: _selectedContactName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: AppColors.disabled),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _showTemplateSelector,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.description_outlined,
                        size: 20, color: AppColors.textMuted),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Utiliser un modèle',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 20, color: AppColors.disabled),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.label),
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              maxLines: 6,
              minLines: 4,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$_charCount / 160',
                style: TextStyle(
                  fontSize: 12,
                  color: _charCount > 160
                      ? AppColors.error
                      : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildScheduleToggle(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isSending ? null : _sendOrSchedule,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : Text(
                        _isScheduled
                            ? "Planifier l'envoi"
                            : 'Envoyer maintenant',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.schedule, size: 20, color: AppColors.indigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Planifier l'envoi",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_isScheduled && _scheduledAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('dd MMM yyyy à HH:mm', 'fr')
                        .format(_scheduledAt!),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: _isScheduled,
            activeThumbColor: AppColors.primary,
            onChanged: _toggleSchedule,
          ),
        ],
      ),
    );
  }
}

class _SmsTemplate {
  const _SmsTemplate({
    required this.id,
    required this.name,
    required this.body,
  });

  final String id;
  final String name;
  final String body;
}

class _ContactPickerSheet extends StatefulWidget {
  const _ContactPickerSheet({
    required this.contacts,
    required this.isLoading,
    required this.scrollController,
    required this.onContactSelected,
  });

  final List<LeadItem> contacts;
  final bool isLoading;
  final ScrollController scrollController;
  final ValueChanged<LeadItem> onContactSelected;

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  String _filterQuery = '';

  List<LeadItem> get _filtered {
    if (_filterQuery.isEmpty) return widget.contacts;
    final q = _filterQuery.toLowerCase();
    return widget.contacts
        .where((c) =>
            c.fullName.toLowerCase().contains(q) ||
            c.phone.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Choisir un contact',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textMuted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onChanged: (v) => setState(() => _filterQuery = v),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? const Center(
                      child: Text('Aucun contact trouvé',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final lead = _filtered[index];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary
                                .withValues(alpha: 0.1),
                            child: Text(
                              lead.fullName.isNotEmpty
                                  ? lead.fullName
                                      .split(RegExp(r'\s+'))
                                      .take(2)
                                      .map((w) =>
                                          w.isNotEmpty ? w[0] : '')
                                      .join()
                                      .toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(lead.fullName),
                          subtitle: Text(lead.phone),
                          onTap: () => widget.onContactSelected(lead),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
