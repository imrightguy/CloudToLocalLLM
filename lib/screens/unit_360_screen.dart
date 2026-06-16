import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/unit_360_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/error_state.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

/// Vue 360° d'une unité — agrège bail, maintenance, communications, rénovation.
class Unit360Screen extends StatefulWidget {
  const Unit360Screen({super.key, required this.unitId});

  final String unitId;

  @override
  State<Unit360Screen> createState() => _Unit360ScreenState();
}

class _Unit360ScreenState extends State<Unit360Screen> {
  Unit360Data? _data;
  bool _isLoading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await Unit360Service.instance.getUnit360(widget.unitId);
      if (!mounted) return;
      setState(() { _data = data; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: _data?.unit.number ?? 'Unité ${widget.unitId.substring(0, 8)}…',
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetch),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: false);
    if (_error != null) return ErrorState(error: _error!, onRetry: _fetch);
    if (_data == null) return const ErrorState(error: 'Aucune donnée');

    final d = _data!;
    final fmt = NumberFormat.currency(locale: 'fr_CA', symbol: '\$', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: _fetch,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUnitHeader(d, fmt),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionTitle('Bail actif', Icons.description_outlined),
            const SizedBox(height: AppSpacing.sm),
            d.activeLease != null ? _buildLeaseCard(d.activeLease!, fmt) : _buildEmptyCard('Aucun bail actif'),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionTitle('Maintenance', Icons.build_outlined,
              badge: d.maintenanceTickets.where((t) => t.status != 'done' && t.status != 'cancelled').length),
            const SizedBox(height: AppSpacing.sm),
            d.maintenanceTickets.isNotEmpty
                ? _buildTicketList(d.maintenanceTickets)
                : _buildEmptyCard('Aucun ticket de maintenance'),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionTitle('Communications', Icons.chat_outlined,
              badge: d.communications.length),
            const SizedBox(height: AppSpacing.sm),
            d.communications.isNotEmpty
                ? _buildCommList(d.communications)
                : _buildEmptyCard('Aucune communication'),
            const SizedBox(height: AppSpacing.xl),
            _buildSectionTitle('Rénovation', Icons.handyman_outlined),
            const SizedBox(height: AppSpacing.sm),
            d.renovation != null ? _buildRenovationCard(d) : _buildEmptyCard('Aucun chantier de rénovation'),
            const SizedBox(height: AppSpacing.xl + 32),
          ],
        ),
      ),
    );
  }

  // ── Unit header ──

  Widget _buildUnitHeader(Unit360Data d, NumberFormat fmt) {
    final u = d.unit;
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(u.number, style: AppTypography.sectionHeader)),
              StatusBadge(label: u.status, variant: _unitStatusVariant(u.status)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text('${d.buildingName} · ${d.buildingAddress}, ${d.buildingCity}',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
              _metricChip('Loyer', fmt.format(u.rent / 100)),
              _metricChip('Chambres', '${u.bedrooms}'),
              _metricChip('SDB', '${u.bathrooms}'),
              if (u.squareFeet != null) _metricChip('Superficie', '${u.squareFeet} pi²'),
            ]),
            if (u.tenantName != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(u.tenantName!, style: AppTypography.body),
                if (u.tenantPhone != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  const Icon(Icons.phone_outlined, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(u.tenantPhone!, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                ],
              ]),
            ],
          ],
        ),
      ),
    );
  }

  BadgeVariant _unitStatusVariant(String status) {
    switch (status) {
      case 'occupied': return BadgeVariant.success;
      case 'vacant': return BadgeVariant.warning;
      case 'maintenance': return BadgeVariant.info;
      case 'ready_for_leasing': return BadgeVariant.info;
      default: return BadgeVariant.neutral;
    }
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text('$label: $value', style: AppTypography.caption.copyWith(color: AppColors.primary)),
    );
  }

  // ── Lease card ──

  Widget _buildLeaseCard(LeaseItem lease, NumberFormat fmt) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusBadge(label: lease.leaseStatus.label, variant: _leaseBadgeVariant(lease.leaseStatus)),
              const Spacer(),
              Text('${fmt.format((lease.monthlyRent ?? 0) / 100)}/mois',
                style: AppTypography.cardTitle.copyWith(color: AppColors.primary)),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (lease.tenantName != null)
              _infoRow('Locataire', lease.tenantName!),
            if (lease.tenantEmail != null)
              _infoRow('Courriel', lease.tenantEmail!),
            if (lease.tenantPhone != null)
              _infoRow('Téléphone', lease.tenantPhone!),
            if (lease.startDate != null)
              _infoRow('Début', DateFormat('dd MMM yyyy', 'fr').format(lease.startDate!)),
            if (lease.endDate != null)
              _infoRow('Fin', DateFormat('dd MMM yyyy', 'fr').format(lease.endDate!)),
            if (lease.notes != null && lease.notes!.isNotEmpty)
              _infoRow('Notes', lease.notes!),
          ],
        ),
      ),
    );
  }

  BadgeVariant _leaseBadgeVariant(LeaseStatus status) {
    switch (status) {
      case LeaseStatus.active: return BadgeVariant.success;
      case LeaseStatus.signed: return BadgeVariant.info;
      case LeaseStatus.sent: return BadgeVariant.warning;
      case LeaseStatus.draft: return BadgeVariant.neutral;
      case LeaseStatus.terminated: return BadgeVariant.danger;
    }
  }

  // ── Maintenance tickets ──

  Widget _buildTicketList(List<MaintenanceTaskItem> tickets) {
    return Column(
      children: tickets.take(10).map((t) => Card(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            StatusBadge(label: t.status, variant: _ticketStatusVariant(t.status)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (t.buildingName != null)
                  Text(t.buildingName!, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            )),
          ]),
        ),
      )).toList(),
    );
  }

  BadgeVariant _ticketStatusVariant(String status) {
    switch (status) {
      case 'open': case 'todo': return BadgeVariant.warning;
      case 'in_progress': return BadgeVariant.info;
      case 'done': case 'completed': return BadgeVariant.success;
      case 'blocked': return BadgeVariant.danger;
      default: return BadgeVariant.neutral;
    }
  }

  // ── Communications ──

  Widget _buildCommList(List<CommunicationItem> comms) {
    return Column(
      children: comms.take(10).map((c) => Card(
        color: AppColors.surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(children: [
            Icon(_commIcon(c.direction), size: 18, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.subject.isNotEmpty ? c.subject : c.body,
                  style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(DateFormat('dd MMM yyyy HH:mm', 'fr').format(c.createdAt),
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            )),
            StatusBadge(label: c.status, variant: c.status == 'sent' || c.status == 'delivered' ? BadgeVariant.success : BadgeVariant.neutral),
          ]),
        ),
      )).toList(),
    );
  }

  IconData _commIcon(String direction) {
    switch (direction) {
      case 'outbound': return Icons.call_made_rounded;
      case 'inbound': return Icons.call_received_rounded;
      default: return Icons.chat_bubble_outline_rounded;
    }
  }

  // ── Renovation ──

  Widget _buildRenovationCard(Unit360Data d) {
    final r = d.renovation;
    if (r == null) return _buildEmptyCard('Aucun chantier');

    final readiness = d.readiness;
    final opsStatus = readiness?['opsStatus'] as String? ?? 'inconnu';
    final leasingStatus = readiness?['leasingStatus'] as String? ?? 'inconnu';
    final blockingCount = readiness?['blockingCount'] as int? ?? 0;

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              StatusBadge(label: r['status'] as String? ?? '?', variant: _renoStatusVariant(r['status'] as String? ?? '')),
              const Spacer(),
              if (leasingStatus == 'ready')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: const Text('Prêt à louer', style: TextStyle(fontSize: 12, color: AppColors.success)),
                ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(r['title'] as String? ?? 'Sans titre', style: AppTypography.cardTitle),
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: [
              _metricChip('État opérationnel', opsStatus),
              _metricChip('Blocages', '$blockingCount'),
              if (readiness?['blockingSummary'] != null)
                _metricChip('Détail', readiness!['blockingSummary'] as String),
            ]),
          ],
        ),
      ),
    );
  }

  BadgeVariant _renoStatusVariant(String status) {
    switch (status) {
      case 'active': return BadgeVariant.info;
      case 'blocked': return BadgeVariant.danger;
      case 'ready_for_leasing': case 'completed': return BadgeVariant.success;
      case 'planned': return BadgeVariant.neutral;
      default: return BadgeVariant.neutral;
    }
  }

  // ── Shared widgets ──

  Widget _buildSectionTitle(String title, IconData icon, {int? badge}) {
    return Row(children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: AppSpacing.sm),
      Text(title, style: AppTypography.sectionHeader),
      if (badge != null && badge > 0) ...[
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text('$badge', style: AppTypography.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
        ),
      ],
    ]);
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(message, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted))),
        Expanded(child: Text(value, style: AppTypography.body)),
      ]),
    );
  }
}
