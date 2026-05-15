import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  DateTime _selectedDate = DateTime.now();
  List<VisitItem> _allVisits = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchVisits();
  }

  Future<void> _fetchVisits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await ApiService.instance.get('/visits');
      final data = response['data'] as List<dynamic>;
      final visits = data
          .map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _allVisits = visits;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Filter visits that match the selected date (compare date part of dateTime).
  List<VisitItem> get _filteredVisits {
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return _allVisits.where((v) {
      if (v.dateTime == null) return false;
      final visitDate = DateTime(
        v.dateTime!.year,
        v.dateTime!.month,
        v.dateTime!.day,
      );
      return visitDate.isAtSameMomentAs(selected);
    }).toList();
  }

  /// Count visits by status for selected date.
  int _countByStatus(String status) {
    return _filteredVisits
        .where((v) => v.status.toLowerCase() == status)
        .length;
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'no_show':
        return 'Absent';
      case 'scheduled':
        return 'Planifiée';
      default:
        return status;
    }
  }

  bool _isConfirmed(String status) {
    return status.toLowerCase() == 'confirmed';
  }

  int _countConfirmedTenant(List<VisitItem> visits) {
    return visits.where((visit) => visit.tenantConfirmed).length;
  }

  int _countConfirmedEmployee(List<VisitItem> visits) {
    return visits.where((visit) => visit.employeeConfirmed).length;
  }

  int _countPendingTenant(List<VisitItem> visits) {
    return visits.where((visit) => visit.occupantNotified && !visit.tenantConfirmed).length;
  }

  int _countRemindersQueued(List<VisitItem> visits) {
    return visits.where((visit) =>
        visit.morningReminderSentAt != null ||
        visit.reminder24hQueuedAt != null ||
        visit.reminder2hQueuedAt != null).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Visites', actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateVisitDialog(context),
          ),
        ]),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger les visites',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchVisits,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredVisits;
    final total = filtered.length;
    final confirmed = _countByStatus('confirmed');
    final pending = _countByStatus('scheduled');
    final tenantConfirmed = _countConfirmedTenant(filtered);
    final employeeConfirmed = _countConfirmedEmployee(filtered);
    final pendingTenant = _countPendingTenant(filtered);
    final remindersQueued = _countRemindersQueued(filtered);

    return RefreshIndicator(
      onRefresh: _fetchVisits,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date selector
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.subtract(const Duration(days: 1));
                    });
                  },
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('EEEE d MMMM yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate =
                          _selectedDate.add(const Duration(days: 1));
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats summary
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppSpacing.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Visites aujourd'hui",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$total',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppSpacing.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Confirmées',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$confirmed',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppSpacing.cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Potentielles',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$pending',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StateSummaryCard(
                  label: 'Locataires confirmés',
                  value: '$tenantConfirmed',
                  color: AppColors.success,
                  icon: Icons.verified_user_outlined,
                ),
                _StateSummaryCard(
                  label: 'Employés confirmés',
                  value: '$employeeConfirmed',
                  color: AppColors.primary,
                  icon: Icons.badge_outlined,
                ),
                _StateSummaryCard(
                  label: 'Locataires en attente',
                  value: '$pendingTenant',
                  color: AppColors.warning,
                  icon: Icons.schedule_outlined,
                ),
                _StateSummaryCard(
                  label: 'Rappels planifiés',
                  value: '$remindersQueued',
                  color: AppColors.info,
                  icon: Icons.notifications_active_outlined,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Upcoming visits
            const Text(
              'Visites à venir',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            if (filtered.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucune visite pour cette date',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final visit = filtered[index];
                  final isConfirmed = _isConfirmed(visit.status);
                  final statusColor = isConfirmed
                      ? AppColors.success
                      : AppColors.warning;
                  final displayStatus = _statusLabel(visit.status);
                  final timeLabel = visit.dateTime != null
                      ? DateFormat('HH:mm').format(visit.dateTime!)
                      : visit.dateLabel;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isConfirmed
                                        ? Icons.check_circle_outlined
                                        : Icons.schedule_outlined,
                                    color: statusColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            timeLabel,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              displayStatus,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: statusColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          // Pending occupant response badge
                                          if (visit.occupantNotified &&
                                              !visit.tenantConfirmed) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.hourglass_top,
                                                      size: 10,
                                                      color: AppColors.warning),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'Locataire',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.warning,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        visit.buildingName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  visit.agent,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.apartment_outlined,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    visit.unitLabel,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (visit.notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                visit.notes,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (_visitLifecycleSummary(visit).isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                _visitLifecycleSummary(visit),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        _showVisitDetailDialog(context, visit),
                                    child: const Text(
                                      'Détails',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: isConfirmed
                                        ? null
                                        : () => _confirmVisit(visit),
                                    child: const Text(
                                      'Confirmer',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.surface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showVisitDetailDialog(BuildContext context, VisitItem visit) {
    final displayStatus = _statusLabel(visit.status);
    final timeLabel = visit.dateTime != null
        ? DateFormat('EEEE d MMMM yyyy à HH:mm').format(visit.dateTime!)
        : visit.dateLabel;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Détails de la visite'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Date', timeLabel),
                _detailRow('Statut', displayStatus),
                _detailRow('Immeuble', visit.buildingName),
                _detailRow('Unité', visit.unitLabel),
                _detailRow('Agent', visit.agent),
                if (visit.leadName != null && visit.leadName!.isNotEmpty)
                  _detailRow('Prospect', visit.leadName!),
                if (visit.notes.isNotEmpty) _detailRow('Notes', visit.notes),
                if (visit.tenantConfirmationRequestedAt != null)
                  _detailRow('Confirmation locataire demandée', _formatTimestamp(visit.tenantConfirmationRequestedAt!)),
                if (visit.tenantConfirmedAt != null)
                  _detailRow('Locataire confirmé le', _formatTimestamp(visit.tenantConfirmedAt!)),
                if (visit.tenantDeclinedAt != null)
                  _detailRow('Locataire a refusé le', _formatTimestamp(visit.tenantDeclinedAt!)),
                if (visit.employeeConfirmationRequestedAt != null)
                  _detailRow('Confirmation employé demandée', _formatTimestamp(visit.employeeConfirmationRequestedAt!)),
                if (visit.employeeConfirmedAt != null)
                  _detailRow('Employé confirmé le', _formatTimestamp(visit.employeeConfirmedAt!)),
                if (visit.employeeDeclinedAt != null)
                  _detailRow('Employé a refusé le', _formatTimestamp(visit.employeeDeclinedAt!)),
                if (visit.morningReminderSentAt != null)
                  _detailRow('Rappel du matin envoyé le', _formatTimestamp(visit.morningReminderSentAt!)),
                if (visit.reminder24hQueuedAt != null)
                  _detailRow('Rappel 24h planifié le', _formatTimestamp(visit.reminder24hQueuedAt!)),
                if (visit.reminder2hQueuedAt != null)
                  _detailRow('Rappel 2h planifié le', _formatTimestamp(visit.reminder2hQueuedAt!)),
                _detailRow('Préavis rappel matin', visit.morningOfSent ? 'Oui' : 'Non'),
                const SizedBox(height: 8),
                // Occupant notification status
                _occupantStatusRow(visit),
                Row(
                  children: [
                    const Text('Employé confirmé: ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    Text(visit.employeeConfirmed ? 'Oui' : 'Non'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  String _visitLifecycleSummary(VisitItem visit) {
    final parts = <String>[];

    if (visit.tenantConfirmed) {
      parts.add('Locataire confirmé');
    } else if (visit.tenantConfirmationRequestedAt != null) {
      parts.add('Locataire à confirmer');
    } else if (visit.occupantNotified) {
      parts.add('Locataire notifié');
    }

    if (visit.employeeConfirmed) {
      parts.add('Employé confirmé');
    } else if (visit.employeeConfirmationRequestedAt != null) {
      parts.add('Employé à confirmer');
    }

    if (visit.morningReminderSentAt != null) {
      parts.add('Rappel matin envoyé');
    } else if (visit.reminder24hQueuedAt != null) {
      parts.add('Rappel 24h en file');
    } else if (visit.reminder2hQueuedAt != null) {
      parts.add('Rappel 2h en file');
    }

    return parts.join(' · ');
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return DateFormat('d MMM yyyy à HH:mm', 'fr').format(dateTime);
  }

  /// Display the occupant notification & tenant confirmation status with icons.
  Widget _occupantStatusRow(VisitItem visit) {
    if (!visit.occupantNotified && !visit.tenantConfirmed) {
      // No notification sent — show a neutral grey indicator
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.notifications_none, size: 16, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Locataire non notifié',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (visit.tenantConfirmed) {
      // Tenant confirmed — green checkmark
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Locataire notifié et confirmé',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Notified but not confirmed — orange/yellow pending indicator
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: AppColors.warning),
          SizedBox(width: 6),
          Text(
            'Locataire notifié — en attente de confirmation',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.warning,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmVisit(VisitItem visit) async {
    if (visit.id == null) return;
    try {
      await ApiService.instance
          .patch('/visits/${visit.id}/status', {'status': 'confirmed'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visite confirmée'),
            backgroundColor: AppColors.success,
          ),
        );
        _fetchVisits();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showCreateVisitDialog(BuildContext context) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => const _CreateVisitScreen(),
        fullscreenDialog: true,
      ),
    )
        .then((_) {
      if (mounted) _fetchVisits();
    });
  }
}

class _StateSummaryCard extends StatelessWidget {
  const _StateSummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Create Visit — full-screen dialog with dropdown pickers
// =============================================================================

class _CreateVisitScreen extends StatefulWidget {
  const _CreateVisitScreen();

  @override
  State<_CreateVisitScreen> createState() => _CreateVisitScreenState();
}

class _CreateVisitScreenState extends State<_CreateVisitScreen> {
  bool _isLoading = true;
  String? _error;

  // Fetched options
  List<UnitItem> _units = [];
  List<LeadItem> _leads = [];
  List<Map<String, dynamic>> _employees = [];

  // Selected values
  String? _selectedUnitId;
  String? _selectedLeadId;
  String? _selectedEmployeeId;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay.now().replacing(
    hour: DateTime.now().add(const Duration(hours: 1)).hour,
  );
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  Future<void> _fetchOptions() async {
    try {
      final results = await Future.wait([
        ApiService.instance.get('/buildings/units?limit=100'),
        ApiService.instance.get('/leads?limit=100'),
        ApiService.instance.get('/employees?limit=100'),
      ]);

      setState(() {
        _units = (results[0]['data'] as List<dynamic>?)
                ?.map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _leads = (results[1]['data'] as List<dynamic>?)
                ?.map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _employees = (results[2]['data'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .toList() ??
            [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _unitLabel(UnitItem u) =>
      '${u.number} — ${u.type} (${u.bedrooms}ch, ${u.rent}\$)';

  String _leadLabel(LeadItem l) => '${l.fullName} (${l.stage.label})';

  String _employeeLabel(Map<String, dynamic> e) {
    final first = e['firstName'] as String? ?? '';
    final last = e['lastName'] as String? ?? '';
    return '$first $last'.trim();
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null ||
        _selectedLeadId == null ||
        _selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final result = await ApiService.instance.post('/visits', {
        'unitId': _selectedUnitId,
        'leadId': _selectedLeadId,
        'employeeId': _selectedEmployeeId,
        'dateTime': dt.toIso8601String(),
      });

      if (mounted) {
        final confirmationSMS = result['confirmationSMS'] as Map<String, dynamic>?;
        final occupantSMS = result['occupantSMS'] as Map<String, dynamic>?;
        final noticeMessages = <String>[];
        var hasFailure = false;
        var needsNotice = false;

        Map<String, dynamic>? nestedResult(Object? value) => value is Map<String, dynamic> ? value : null;

        String? smsLine(String label, Map<String, dynamic>? smsResult) {
          if (smsResult == null) return null;
          final success = smsResult['success'] as bool? ?? false;
          final error = smsResult['error'] is Map<String, dynamic>
              ? (smsResult['error'] as Map<String, dynamic>)['message'] as String?
              : smsResult['error'] as String?;
          final notice = smsResult['needsNotice'] as bool? ?? false;
          needsNotice = needsNotice || notice;
          if (success) {
            return notice ? '✅ $label envoyé (préavis court)' : '✅ $label envoyé';
          }
          hasFailure = true;
          return error == null || error.isEmpty ? '⚠️ $label: échec' : '⚠️ $label: $error';
        }

        final employeeSms = nestedResult(confirmationSMS?['employee']);
        final tenantSms = nestedResult(confirmationSMS?['tenant']);
        final occupantLine = smsLine('SMS locataire', occupantSMS);
        final employeeLine = smsLine('SMS employé', employeeSms);
        final tenantLine = smsLine('SMS locataire / confirmation', tenantSms);

        if (employeeLine != null) noticeMessages.add(employeeLine);
        if (tenantLine != null) noticeMessages.add(tenantLine);
        if (occupantLine != null) noticeMessages.add(occupantLine);

        if (noticeMessages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Visite créée avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final backgroundColor = hasFailure || needsNotice ? AppColors.warning : AppColors.success;
          final message = noticeMessages.join('\n');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor,
              duration: Duration(seconds: hasFailure || needsNotice ? 5 : 3),
            ),
          );
        }
        Navigator.of(context).pop();
      }
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Nouvelle visite', leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        )),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchOptions,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Unit picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedUnitId,
                        decoration: const InputDecoration(
                          labelText: 'Unité',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.door_front_door_outlined),
                        ),
                        items: _units.map((u) {
                          return DropdownMenuItem(
                            value: u.id,
                            child: Text(_unitLabel(u),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedUnitId = v),
                      ),
                      const SizedBox(height: 16),

                      // Lead picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedLeadId,
                        decoration: const InputDecoration(
                          labelText: 'Prospect',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        items: _leads.map((l) {
                          return DropdownMenuItem(
                            value: l.id,
                            child: Text(_leadLabel(l),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedLeadId = v),
                      ),
                      const SizedBox(height: 16),

                      // Employee picker
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmployeeId,
                        decoration: const InputDecoration(
                          labelText: 'Employé',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        items: _employees.map((e) {
                          return DropdownMenuItem(
                            value: e['id'] as String?,
                            child: Text(_employeeLabel(e),
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (v) =>
                            setState(() => _selectedEmployeeId = v),
                      ),
                      const SizedBox(height: 16),

                      // Date picker
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 90)),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            DateFormat('d MMMM yyyy', 'fr_CA')
                                .format(_selectedDate),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time picker
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Heure',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.schedule_outlined),
                          ),
                          child: Text(_selectedTime.format(context)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Submit
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Créer la visite',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
