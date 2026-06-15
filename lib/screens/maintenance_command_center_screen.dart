import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/maintenance_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';

class MaintenanceCommandCenterScreen extends StatefulWidget {
  const MaintenanceCommandCenterScreen({super.key});

  @override
  State<MaintenanceCommandCenterScreen> createState() => _MaintenanceCommandCenterScreenState();
}

class _MaintenanceCommandCenterScreenState extends State<MaintenanceCommandCenterScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MaintenanceCommandCenterData _data = _emptyData();
  Map<String, int> _ticketCountsByBuilding = {};

  static MaintenanceCommandCenterData _emptyData() {
    return const MaintenanceCommandCenterData(
      summary: MaintenanceCommandCenterSummary(
        propertyCount: 0,
        renovationCount: 0,
        blockedCount: 0,
        readyCount: 0,
        overdueTaskCount: 0,
        dueSoonTaskCount: 0,
        openOrderCount: 0,
        pendingIntakeCount: 0,
        dispatchableEmployeeCount: 0,
        tenantMessageSentCount: 0,
        tenantMessageFailedCount: 0,
        tenantMessagePendingCount: 0,
      ),
      properties: [],
      backlog: [],
      tenantMessages: [],
      asOf: null,
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchCommandCenter();
  }

  Future<void> _fetchCommandCenter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        MaintenanceService.instance.getCommandCenter(limit: 12),
        _fetchTicketCounts(),
      ]);
      final data = results[0] as MaintenanceCommandCenterData;
      final counts = results[1] as Map<String, int>;
      if (!mounted) return;
      setState(() {
        _data = data;
        _ticketCountsByBuilding = counts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _data = _emptyData();
        _ticketCountsByBuilding = {};
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<Map<String, int>> _fetchTicketCounts() async {
    try {
      final buildingIds = _data.properties.map((p) => p.buildingId).toList();
      if (buildingIds.isEmpty) return {};
      return await MaintenanceService.instance.getOpenTicketCountByBuilding(buildingIds);
    } catch (_) {
      return {};
    }
  }

  bool get _hasNoData => _data.isEmpty;

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '—';
    }
    return DateFormat('d MMM HH:mm', 'fr').format(dateTime.toLocal());
  }

  String _formatDateOnly(DateTime? dateTime) {
    if (dateTime == null) {
      return '—';
    }
    return DateFormat('d MMM', 'fr').format(dateTime.toLocal());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'not_sent':
      case 'unavailable':
        return AppColors.warning;
      default:
        return AppColors.textMuted;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'Envoyé';
      case 'failed':
        return 'Erreur';
      case 'not_sent':
        return 'En attente';
      case 'unavailable':
        return 'Indisponible';
      default:
        return status;
    }
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'ready':
        return 'Prêt';
      case 'blocked':
        return 'Bloqué';
      case 'active':
        return 'En cours';
      default:
        return phase;
    }
  }

  Color _phaseColor(String phase) {
    switch (phase) {
      case 'ready':
        return AppColors.success;
      case 'blocked':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Centre de maintenance',
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _fetchCommandCenter,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchCommandCenter,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(
                      asOf: _data.asOf,
                      propertyCount: _data.summary.propertyCount,
                      errorMessage: _errorMessage,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (_hasNoData) _buildEmptyState(context) else ...[
                      const _SectionHeader(
                        title: 'Indicateurs clés',
                        subtitle: 'Vue d’ensemble de la charge, des blocages et des communications.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          _SummaryCard(label: 'Propriétés', value: _data.summary.propertyCount.toString(), icon: Icons.apartment_outlined, accentColor: AppColors.primary),
                          _SummaryCard(label: 'Rénovations', value: _data.summary.renovationCount.toString(), icon: Icons.construction_outlined, accentColor: AppColors.info),
                          _SummaryCard(label: 'Bloqués', value: _data.summary.blockedCount.toString(), icon: Icons.block_outlined, accentColor: AppColors.error),
                          _SummaryCard(label: 'Prêts', value: _data.summary.readyCount.toString(), icon: Icons.verified_outlined, accentColor: AppColors.success),
                          _SummaryCard(label: 'Tâches en retard', value: _data.summary.overdueTaskCount.toString(), icon: Icons.event_busy_outlined, accentColor: AppColors.error),
                          _SummaryCard(label: 'Tâches à venir', value: _data.summary.dueSoonTaskCount.toString(), icon: Icons.schedule_outlined, accentColor: AppColors.warning),
                          _SummaryCard(label: 'Commandes ouvertes', value: _data.summary.openOrderCount.toString(), icon: Icons.inventory_2_outlined, accentColor: AppColors.info),
                          _SummaryCard(label: 'Demandes', value: _data.summary.pendingIntakeCount.toString(), icon: Icons.mark_email_unread_outlined, accentColor: AppColors.indigo),
                          _SummaryCard(label: 'Dispatchables', value: _data.summary.dispatchableEmployeeCount.toString(), icon: Icons.groups_outlined, accentColor: AppColors.primary),
                          _SummaryCard(label: 'Messages envoyés', value: _data.summary.tenantMessageSentCount.toString(), icon: Icons.sms_outlined, accentColor: AppColors.success),
                          _SummaryCard(label: 'Messages en erreur', value: _data.summary.tenantMessageFailedCount.toString(), icon: Icons.sms_failed_outlined, accentColor: AppColors.error),
                          _SummaryCard(label: 'Messages en attente', value: _data.summary.tenantMessagePendingCount.toString(), icon: Icons.hourglass_bottom_outlined, accentColor: AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (_ticketCountsByBuilding.isNotEmpty) ...[
                        const _SectionHeader(
                          title: 'Tickets de maintenance par bâtiment',
                          subtitle: 'Tickets ouverts et en cours regroupés par immeuble.',
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ..._data.properties.map((property) {
                          final count = _ticketCountsByBuilding[property.buildingId] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _TicketCountCard(
                              buildingName: property.buildingName,
                              buildingId: property.buildingId,
                              ticketCount: count,
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      const _SectionHeader(
                        title: 'Propriétés',
                        subtitle: 'Chaque carte regroupe la charge de rénovation, la capacité et les prochains jalons.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ..._data.properties.map(
                        (property) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _PropertyCard(
                            property: property,
                            formatDate: _formatDateOnly,
                            phaseLabel: _phaseLabel,
                            phaseColor: _phaseColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionHeader(
                        title: 'File de travaux',
                        subtitle: 'Vue priorisée des unités qui nécessitent une intervention ou une relance.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ..._data.backlog.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _BacklogCard(
                            item: item,
                            formatDate: _formatDate,
                            statusLabel: _statusLabel,
                            statusColor: _statusColor,
                            phaseLabel: _phaseLabel,
                            phaseColor: _phaseColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionHeader(
                        title: 'Messages locataires',
                        subtitle: 'État des derniers envois aux occupants concernés par les travaux.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ..._data.tenantMessages.map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _TenantMessageCard(
                            message: message,
                            formatDate: _formatDate,
                            statusLabel: _statusLabel,
                            statusColor: _statusColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 56),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction_outlined, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Aucune donnée de maintenance disponible',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Le tableau de bord s’affichera dès qu’il y aura des rénovations, des équipes ou des messages locataires à suivre.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _fetchCommandCenter,
              icon: const Icon(Icons.refresh),
              label: const Text('Rafraîchir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.asOf,
    required this.propertyCount,
    required this.errorMessage,
  });

  final DateTime? asOf;
  final int propertyCount;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final subtitle = errorMessage == null
        ? 'Vue société active • ${propertyCount == 0 ? 'aucun signal de maintenance' : '$propertyCount propriété(s) suivie(s)'}'
        : 'Vue société active • chargement dégradé';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.construction_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Centre de maintenance',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            asOf == null ? 'Dernière mise à jour: —' : 'Dernière mise à jour: ${DateFormat('d MMM HH:mm', 'fr').format(asOf!.toLocal())}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Impossible de charger le tableau de bord: $message',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 175,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: accentColor.withValues(alpha: 0.15)),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.formatDate,
    required this.phaseLabel,
    required this.phaseColor,
  });

  final MaintenanceCommandCenterProperty property;
  final String Function(DateTime?) formatDate;
  final String Function(String) phaseLabel;
  final Color Function(String) phaseColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.buildingName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.unitCount} unités • ${property.renovationCount} rénovations',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _Chip(label: '${property.capacity.dispatchableCount} dispatchables', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: '${property.blockedCount} bloqués', color: AppColors.error),
              _StatusChip(label: '${property.readyCount} prêts', color: AppColors.success),
              _StatusChip(label: '${property.overdueTaskCount} en retard', color: AppColors.error),
              _StatusChip(label: '${property.dueSoonTaskCount} à venir', color: AppColors.warning),
              _StatusChip(label: '${property.openOrderCount} commandes', color: AppColors.info),
              _StatusChip(label: '${property.pendingIntakeCount} demandes', color: AppColors.indigo),
              _StatusChip(label: '${property.tenantMessageStats.sent}/${property.tenantMessageStats.total} SMS', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InfoBlock(
                  title: 'Capacité',
                  lines: [
                    'Candidats: ${property.capacity.candidateCount}',
                    'Dispatchables: ${property.capacity.dispatchableCount}',
                    'Tâches ouvertes: ${property.capacity.totalOpenTasks}',
                    'Tâches immeuble: ${property.capacity.buildingOpenTasks}',
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoBlock(
                  title: 'Prochain jalon',
                  lines: [
                    'Échéance: ${formatDate(property.nextDueAt)}',
                    'Messagerie: ${property.tenantMessageStats.latestAt == null ? '—' : formatDate(property.tenantMessageStats.latestAt)}',
                    'Bloqué: ${property.blockedCount > 0 ? 'oui' : 'non'}',
                  ],
                ),
              ),
            ],
          ),
          if (property.backlog.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Sous-file',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: property.backlog.map(
                (item) => _BacklogBadge(
                  label: '${item.unitLabel} · ${phaseLabel(item.phase)}',
                  color: phaseColor(item.phase),
                ),
              ).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BacklogCard extends StatelessWidget {
  const _BacklogCard({
    required this.item,
    required this.formatDate,
    required this.statusLabel,
    required this.statusColor,
    required this.phaseLabel,
    required this.phaseColor,
  });

  final MaintenanceCommandCenterBacklogItem item;
  final String Function(DateTime?) formatDate;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final String Function(String) phaseLabel;
  final Color Function(String) phaseColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.buildingName} · Logement ${item.unitLabel}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.readiness} • ${item.taskCount} tâches • ${item.doneCount} terminées',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _Chip(label: phaseLabel(item.phase), color: phaseColor(item.phase)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.nextStep.isNotEmpty ? item.nextStep : 'Étape suivante non définie',
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            item.blockerNote.isNotEmpty ? item.blockerNote : 'Aucun bloqueur principal',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: '${item.overdueTaskCount} en retard', color: AppColors.error),
              _StatusChip(label: '${item.dueSoonTaskCount} à venir', color: AppColors.warning),
              _StatusChip(label: item.assignedEmployeeLabel.isEmpty ? 'Affectation ouverte' : item.assignedEmployeeLabel, color: AppColors.info),
              _StatusChip(label: _formatTenantMessageLabel(item.tenantMessageStatus.status), color: statusColor(item.tenantMessageStatus.status)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mis à jour ${formatDate(item.updatedAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              Text(
                'Échéance ${formatDate(item.nextDueAt)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTenantMessageLabel(String status) {
    switch (status) {
      case 'sent':
        return 'SMS envoyé';
      case 'failed':
        return 'SMS en erreur';
      case 'not_sent':
        return 'SMS à envoyer';
      case 'unavailable':
        return 'SMS indisponible';
      default:
        return status;
    }
  }
}

class _TenantMessageCard extends StatelessWidget {
  const _TenantMessageCard({
    required this.message,
    required this.formatDate,
    required this.statusLabel,
    required this.statusColor,
  });

  final MaintenanceCommandCenterTenantMessage message;
  final String Function(DateTime?) formatDate;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor(message.status).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sms_outlined, color: statusColor(message.status), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${message.buildingName ?? '—'} · ${message.unitLabel ?? 'Logement'}',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    _Chip(label: statusLabel(message.status), color: statusColor(message.status)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message.tenantPhone ?? message.phoneNumber ?? 'Aucun numéro de locataire',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  message.errorMessage?.isNotEmpty == true ? message.errorMessage! : 'Dernier envoi: ${formatDate(message.lastSentAt)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _BacklogBadge extends StatelessWidget {
  const _BacklogBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCountCard extends StatelessWidget {
  const _TicketCountCard({
    required this.buildingName,
    required this.buildingId,
    required this.ticketCount,
  });

  final String buildingName;
  final String buildingId;
  final int ticketCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed('/maintenance-tickets');
        },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ticketCount > 0
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  ticketCount > 0
                      ? Icons.build_outlined
                      : Icons.check_circle_outline,
                  color: ticketCount > 0 ? AppColors.error : AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buildingName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ticketCount > 0
                          ? '$ticketCount ticket${ticketCount > 1 ? 's' : ''} ouvert${ticketCount > 1 ? 's' : ''}'
                          : 'Aucun ticket ouvert',
                      style: TextStyle(
                        fontSize: 13,
                        color: ticketCount > 0
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (ticketCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$ticketCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
