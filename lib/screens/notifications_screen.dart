import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/notifications_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/error_state.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';

/// Centre de notifications — agrège communications, maintenance, visites, paiements.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationsData? _data;
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
      final data = await NotificationsService.instance.fetchAll();
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
        title: 'Notifications',
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetch),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: false);
    if (_error != null) return ErrorState(error: _error!, onRetry: _fetch);
    if (_data == null) return const ErrorState(error: 'Aucune donnée');

    final d = _data!;
    final fmt = DateFormat('dd MMM', 'fr');

    return RefreshIndicator(
      onRefresh: _fetch,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSection(
            title: 'Activité récente',
            icon: Icons.chat_outlined,
            count: d.recentActivity.length,
            route: '/communications',
            emptyMessage: 'Aucune communication récente',
            children: d.recentActivity.take(5).map((c) => _buildCommTile(c, fmt)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            title: 'Tickets de maintenance ouverts',
            icon: Icons.build_outlined,
            count: d.openTickets.length,
            route: '/maintenance-tickets',
            emptyMessage: 'Aucun ticket de maintenance ouvert',
            children: d.openTickets.take(5).map((t) => _buildTicketTile(t)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            title: 'Visites à venir (7 jours)',
            icon: Icons.event_outlined,
            count: d.upcomingVisits.length,
            route: '/visits',
            emptyMessage: 'Aucune visite planifiée',
            children: d.upcomingVisits.take(5).map((v) => _buildVisitTile(v, fmt)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSection(
            title: 'Paiements en retard',
            icon: Icons.warning_amber_rounded,
            count: d.latePayments.length,
            route: '/payments',
            emptyMessage: 'Aucun paiement en retard',
            color: AppColors.warning,
            children: d.latePayments.take(5).map((p) => _buildPaymentTile(p)),
          ),
          const SizedBox(height: AppSpacing.xl + 32),
        ]),
      ),
    );
  }

  // ── Section card ──

  Widget _buildSection({
    required String title,
    required IconData icon,
    required int count,
    required String route,
    required String emptyMessage,
    Color? color,
    required Iterable<Widget> children,
  }) {
    final accent = color ?? AppColors.primary;
    final childList = children.toList();

    return Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.sectionHeader),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text('$count', style: AppTypography.caption.copyWith(
                  color: accent, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ]),
            if (childList.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.sm),
              ...childList,
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              Text(emptyMessage, style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            ],
          ]),
        ),
      ),
    );
  }

  // ── Item tiles ──

  Widget _buildCommTile(CommunicationItem c, DateFormat fmt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        Icon(c.direction == 'inbound' ? Icons.call_received : Icons.call_made,
          size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(
          c.subject.isNotEmpty ? c.subject : c.body,
          style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.sm),
        Text(fmt.format(c.createdAt),
          style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
      ]),
    );
  }

  Widget _buildTicketTile(MaintenanceTaskItem t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        StatusBadge(label: t.status, variant: _ticketVariant(t.status)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(t.title, style: AppTypography.body,
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  BadgeVariant _ticketVariant(String status) {
    switch (status) {
      case 'open': case 'todo': return BadgeVariant.warning;
      case 'in_progress': return BadgeVariant.info;
      case 'blocked': return BadgeVariant.danger;
      default: return BadgeVariant.neutral;
    }
  }

  Widget _buildVisitTile(VisitItem v, DateFormat fmt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        StatusBadge(label: v.status, variant: _visitVariant(v.status)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v.unitLabel.isNotEmpty ? v.unitLabel : v.buildingName,
            style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (v.dateTime != null)
            Text(fmt.format(v.dateTime!),
              style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ])),
      ]),
    );
  }

  BadgeVariant _visitVariant(String status) {
    switch (status) {
      case 'scheduled': return BadgeVariant.info;
      case 'confirmed': return BadgeVariant.success;
      case 'completed': return BadgeVariant.success;
      case 'cancelled': return BadgeVariant.danger;
      case 'no_show': return BadgeVariant.warning;
      default: return BadgeVariant.neutral;
    }
  }

  Widget _buildPaymentTile(Map<String, dynamic> p) {
    final amount = (p['amountCents'] as num?)?.toInt() ?? 0;
    final unit = p['unitLabel'] as String? ?? p['unit']?['label'] as String? ?? '?';
    final dueDate = p['dueDate'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(children: [
        const Icon(Icons.payment_outlined, size: 16, color: AppColors.warning),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(unit,
          style: AppTypography.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: AppSpacing.sm),
        Text('${(amount / 100).toStringAsFixed(0)} \$',
          style: AppTypography.body.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
        if (dueDate.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(dueDate, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ]),
    );
  }
}
