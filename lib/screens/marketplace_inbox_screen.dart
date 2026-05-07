import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../models.dart';
import '../services/communication_service.dart';
import '../services/visit_service.dart';
import '../services/building_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';
import 'conversation_detail_screen.dart';
import 'sms_conversation_screen.dart';
import 'visit_form_screen.dart';
import 'calendar_screen.dart';

class MarketplaceInboxScreen extends StatefulWidget {
  const MarketplaceInboxScreen({super.key});

  @override
  State<MarketplaceInboxScreen> createState() => _MarketplaceInboxScreenState();
}

class _MarketplaceInboxScreenState extends State<MarketplaceInboxScreen> {
  List<MarketplaceInboxThread> _threads = [];
  List<VisitItem> _upcomingVisits = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await initializeDateFormatting('fr', null);
      await initializeDateFormatting('fr_CA', null);
      final now = DateTime.now();
      final visitWindowStart = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2));
      final visitWindowEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).add(const Duration(days: 30));

      final results = await Future.wait<dynamic>([
        CommunicationService.instance.getMarketplaceInboxThreads(
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
          page: 1,
          limit: 50,
        ),
        VisitService.instance.getVisits(
          dateFrom: visitWindowStart,
          dateTo: visitWindowEnd,
          limit: 50,
          forceRefresh: true,
        ),
      ]);

      final visitsPage = results[1] as PaginatedResult<VisitItem>;
      if (!mounted) return;
      setState(() {
        _threads = results[0] as List<MarketplaceInboxThread>;
        _upcomingVisits = visitsPage.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<MarketplaceInboxThread> get _filteredThreads {
    return _threads.where((item) {
      if (_searchQuery.isNotEmpty) {
        final haystack = [
          item.contactName,
          item.contactPhone,
          item.coordinationState,
          item.lastMessage?.subject ?? '',
          item.lastMessage?.body ?? '',
          item.lastMessage?.type ?? '',
          item.lastMessage?.status ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      if (_selectedFilter == 'all') return true;
      if (_selectedFilter == 'failed') {
        return item.lastMessage?.status.toLowerCase() == 'failed';
      }
      if (_selectedFilter == 'sms' || _selectedFilter == 'email' || _selectedFilter == 'call' || _selectedFilter == 'fb_messenger') {
        return item.lastMessage?.type.toLowerCase() == _selectedFilter;
      }
      return true;
    }).toList();
  }

  List<VisitItem> get _sortedUpcomingVisits {
    final visits = List<VisitItem>.from(_upcomingVisits);
    visits.sort((a, b) {
      final aTime = a.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.dateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
    return visits.where((visit) {
      final dt = visit.dateTime;
      if (dt == null) return false;
      return dt.isAfter(DateTime.now().subtract(const Duration(days: 1)));
    }).toList();
  }

  int get _inboundCount =>
      _threads.where((item) => item.lastMessage?.direction.toLowerCase() == 'inbound' || item.needsResponse).length;

  int get _responseNeededCount => _threads.where((item) => item.needsResponse).length;

  int get _followUpCount => _threads.where((item) => item.firstResponseAt != null).length;

  int get _visitCount => _sortedUpcomingVisits.length;

  void _updateFilter(String filter) {
    setState(() => _selectedFilter = filter);
    _fetchInbox();
  }

  String _suggestedAction(MarketplaceInboxThread item) {
    final lastMessage = item.lastMessage;
    if (item.needsResponse) return 'Répondre';
    if (item.coordinationState == 'scheduled' || item.coordinationState == 'confirmed') return 'Visite';
    if (item.coordinationState == 'follow_up_required') return 'Relancer';
    if (lastMessage?.status.toLowerCase() == 'failed') return 'Réessayer';
    switch (lastMessage?.type.toLowerCase()) {
      case 'sms':
        return 'Relancer';
      case 'fb_messenger':
        return 'Qualifier';
      case 'email':
        return 'Planifier';
      case 'call':
        return 'Rappeler';
      default:
        return 'Voir';
    }
  }

  Future<void> _openThread(MarketplaceInboxThread item) async {
    final contactId = item.contactId.isNotEmpty ? item.contactId : (item.leadId ?? '');
    final contactName = item.contactName.isNotEmpty ? item.contactName : 'Prospect';
    final contactPhone = item.contactPhone;
    final contactInitials = item.contactInitials;
    if (item.lastMessage?.type.toLowerCase() == 'sms') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SmsConversationScreen(
            contactId: contactId,
            contactName: contactName,
            contactPhone: contactPhone,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConversationDetailScreen(
            contactId: contactId,
            contactName: contactName,
            contactPhone: contactPhone,
            contactInitials: contactInitials,
          ),
        ),
      );
    }
  }

  Future<void> _openBooking({DateTime? initialDate, String? leadId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (_) => VisitFormScreen(
          initialDate: initialDate,
          initialLeadId: leadId,
        ),
      ),
    );
    if (mounted) {
      _fetchInbox();
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('d MMM HH:mm', 'fr').format(dateTime);
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'sms':
        return 'SMS';
      case 'fb_messenger':
        return 'Messenger';
      case 'email':
        return 'Courriel';
      case 'call':
        return 'Appel';
      case 'note':
        return 'Note';
      default:
        return type.toUpperCase();
    }
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'sms':
        return AppColors.primary;
      case 'fb_messenger':
        return AppColors.indigo;
      case 'email':
        return AppColors.info;
      case 'call':
        return AppColors.success;
      case 'note':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _visitBadge(VisitItem visit) {
    final dateTime = visit.dateTime;
    if (dateTime == null) return visit.status;
    final isToday = DateTime(dateTime.year, dateTime.month, dateTime.day)
        .isAtSameMomentAs(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));
    if (isToday && visit.status.toLowerCase() == 'scheduled') {
      return 'Aujourd’hui';
    }
    return _formatTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Boîte de réception',
        actions: [
          IconButton(
            tooltip: 'Planifier une visite',
            icon: const Icon(Icons.event_available_outlined),
            onPressed: () => _openBooking(initialDate: DateTime.now().add(const Duration(hours: 1))),
          ),
          IconButton(
            tooltip: 'Rafraîchir',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInbox,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _fetchInbox,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _buildSummaryRow(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSearchBar(),
                      const SizedBox(height: AppSpacing.md),
                      _buildFilterChips(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildVisitsPanel(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildInboxHeader(),
                      const SizedBox(height: AppSpacing.sm),
                      if (_filteredThreads.isEmpty)
                        _buildEmptyInbox()
                      else
                        ..._filteredThreads.map(_buildInboxItem),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Planifier'),
        onPressed: () => _openBooking(initialDate: DateTime.now().add(const Duration(hours: 1))),
      ),
    );
  }

  Widget _buildSummaryRow() {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        _SummaryCard(
          label: 'À traiter',
          value: '$_responseNeededCount',
          icon: Icons.mark_email_unread_outlined,
          color: AppColors.error,
        ),
        _SummaryCard(
          label: 'Réponses',
          value: '$_followUpCount',
          icon: Icons.reply_outlined,
          color: AppColors.primary,
        ),
        _SummaryCard(
          label: 'Messages entrants',
          value: '$_inboundCount',
          icon: Icons.inbox_outlined,
          color: AppColors.warning,
        ),
        _SummaryCard(
          label: 'Visites à venir',
          value: '$_visitCount',
          icon: Icons.event_available_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: AppSpacing.cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher un nom, un numéro ou un message',
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
                _fetchInbox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = [
      const _FilterOption(label: 'Tous', value: 'all'),
      const _FilterOption(label: 'SMS', value: 'sms'),
      const _FilterOption(label: 'Messenger', value: 'fb_messenger'),
      const _FilterOption(label: 'Courriel', value: 'email'),
      const _FilterOption(label: 'Appels', value: 'call'),
      const _FilterOption(label: 'Échoués', value: 'failed'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(chip.label),
                  selected: _selectedFilter == chip.value,
                  onSelected: (_) => _updateFilter(chip.value),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildVisitsPanel() {
    final visits = _sortedUpcomingVisits.take(3).toList();
    return Container(
      decoration: AppSpacing.cardDecoration(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_available_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Visites à venir',
                  style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CalendarScreen()),
                ),
                child: const Text('Calendrier'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (visits.isEmpty)
            const Text(
              'Aucune visite planifiée pour les prochaines semaines.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Column(
              children: visits
                  .map(
                    (visit) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _VisitPreviewCard(
                        visit: visit,
                        badge: _visitBadge(visit),
                        onTap: () => _openBooking(
                          initialDate: visit.dateTime ?? DateTime.now(),
                          leadId: visit.leadId,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInboxHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Messages à traiter',
            style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
          ),
        ),
        Text(
          '${_filteredThreads.length} conversation${_filteredThreads.length == 1 ? '' : 's'}',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Impossible de charger la boîte de réception',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _fetchInbox,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInbox() {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: AppSpacing.cardDecoration(),
      child: const Column(
        children: [
          Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: AppSpacing.md),
          Text(
            'Aucune conversation ne correspond à ce filtre',
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'Essayez un autre canal ou revenez à Tous pour voir les demandes ouvertes.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _coordinationStateLabel(String state) {
    switch (state.toLowerCase()) {
      case 'message_only':
        return 'À qualifier';
      case 'awaiting_employee_confirmation':
        return 'Attente employé';
      case 'awaiting_tenant_confirmation':
        return 'Attente locataire';
      case 'scheduled':
        return 'Planifiée';
      case 'confirmed':
        return 'Confirmée';
      case 'in_progress':
        return 'En cours';
      case 'follow_up_required':
        return 'Relance';
      case 'completed_interested':
        return 'Intéressé';
      case 'completed_not_interested':
        return 'Pas intéressé';
      case 'completed_no_show':
        return 'No-show';
      case 'cancelled':
        return 'Annulée';
      default:
        return state;
    }
  }

  String _firstResponseLabel(MarketplaceInboxThread item) {
    if (item.needsResponse) {
      return 'En attente de réponse';
    }
    final minutes = item.firstResponseDelayMinutes;
    if (minutes == null) {
      return 'Réponse reçue';
    }
    if (minutes < 60) {
      return 'Réponse en $minutes min';
    }
    final hours = (minutes / 60).floor();
    final remainder = minutes % 60;
    return remainder == 0 ? 'Réponse en $hours h' : 'Réponse en $hours h $remainder min';
  }

  Widget _buildInboxItem(MarketplaceInboxThread item) {
    final action = _suggestedAction(item);
    final direction = item.lastMessage?.direction.toLowerCase() == 'inbound' ? 'Entrant' : 'Sortant';
    final previewText = item.lastMessage?.body.isNotEmpty == true
        ? item.lastMessage!.body
        : item.lastMessage?.subject.isNotEmpty == true
            ? item.lastMessage!.subject
            : 'Aucun message enregistré';
    final type = item.lastMessage?.type ?? 'note';
    final lastActivityLabel = item.lastMessageAt != null ? _formatTime(item.lastMessageAt!) : 'Sans activité';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppSpacing.cardDecoration(),
      child: ListTile(
        onTap: () => _openThread(item),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _typeColor(type).withValues(alpha: 0.12),
          foregroundColor: _typeColor(type),
          child: Text(item.contactInitials),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                item.contactName.isNotEmpty ? item.contactName : item.contactPhone,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _Badge(label: _typeLabel(type), color: _typeColor(type)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                previewText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    direction,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  _Badge(
                    label: _coordinationStateLabel(item.coordinationState),
                    color: item.needsResponse ? AppColors.error : AppColors.success,
                  ),
                  _Badge(
                    label: _firstResponseLabel(item),
                    color: item.needsResponse ? AppColors.warning : AppColors.primary,
                  ),
                  Text(
                    lastActivityLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _openThread(item),
              child: Text(action),
            ),
            TextButton(
              onPressed: () => _openBooking(
                initialDate: DateTime.now().add(const Duration(hours: 1)),
                leadId: item.contactId.isNotEmpty ? item.contactId : item.leadId,
              ),
              child: const Text('Visite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: AppSpacing.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitPreviewCard extends StatelessWidget {
  const _VisitPreviewCard({
    required this.visit,
    required this.badge,
    required this.onTap,
  });

  final VisitItem visit;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.event_available_outlined, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${visit.buildingName} · ${visit.unitLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visit.leadName?.isNotEmpty == true ? visit.leadName! : 'Prospect',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    visit.dateTime != null ? _formatVisitTime(visit.dateTime!) : visit.dateLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lifecycleSummary(visit),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Badge(label: visit.status.toUpperCase(), color: AppColors.success),
                const SizedBox(height: 8),
                Text(
                  badge,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatVisitTime(DateTime dt) => DateFormat('d MMM • HH:mm', 'fr').format(dt);

  static String _lifecycleSummary(VisitItem visit) {
    final parts = <String>[];
    if (visit.tenantConfirmedAt != null) parts.add('Locataire confirmé');
    if (visit.employeeConfirmedAt != null) parts.add('Employé confirmé');
    if (visit.morningReminderSentAt != null) parts.add('Rappel matin envoyé');
    if (visit.reminder24hQueuedAt != null) parts.add('Rappel 24h');
    if (visit.reminder2hQueuedAt != null) parts.add('Rappel 2h');
    if (parts.isEmpty) {
      if (visit.tenantConfirmationRequestedAt != null || visit.employeeConfirmationRequestedAt != null) {
        return 'Confirmation demandée';
      }
      return 'Aucune relance encore';
    }
    return parts.join(' · ');
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FilterOption {
  const _FilterOption({required this.label, required this.value});

  final String label;
  final String value;
}
