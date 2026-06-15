import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/fr_dates.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/analytics_service.dart';
import '../services/communication_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/building_perf_row.dart';
import '../widgets/kpi_card.dart';
import '../widgets/lead_funnel.dart';
import 'units_screen.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';
import '../widgets/empty_state.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Incremented on pull-to-refresh. Each [_SectionLoader] listens and reloads
  /// itself independently, forcing a fresh network call.
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);

  PillarsOverview? _pillars;
  bool _pillarsLoading = true;
  Object? _pillarsError;

  @override
  void initState() {
    super.initState();
    _fetchPillars();
  }

  Future<void> _fetchPillars({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() { _pillarsLoading = true; _pillarsError = null; });
    try {
      final pillars = await AnalyticsService.instance.getPillarsOverview(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() { _pillars = pillars; _pillarsLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _pillarsError = e; _pillarsLoading = false; });
    }
  }

  @override
  void dispose() {
    _refreshTick.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    _refreshTick.value++;
    // Let sections enter their loading state so the indicator feels responsive.
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  String _currentPeriodLabel() {
    final now = DateTime.now();
    return '${kFrenchMonths[now.month - 1]} ${now.year}';
  }

  String _formatRevenue(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k \$';
    }
    return '$value \$';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Tableau de bord'),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl + 32,
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNewLeadCard(),
              const SizedBox(height: AppSpacing.lg),
              _buildPeriodSelector(),
              const SizedBox(height: AppSpacing.xl),

              // --- Pilliers (Leasing / Maintenance / Rénovation) -----------
              if (_pillarsLoading)
                const _PillarsSkeleton()
              else if (_pillarsError != null)
                ErrorState(error: _pillarsError!, onRetry: () => _fetchPillars(forceRefresh: true))
              else if (_pillars != null)
                _buildPillarsSection(_pillars!),
              const SizedBox(height: AppSpacing.xl),

              // --- Analytics (KPIs, entonnoir, pipeline, visites, inbox) ---
              _SectionLoader<FullDashboardData>(
                refreshTick: _refreshTick,
                skeleton: const _AnalyticsSkeleton(),
                fetcher: ({required bool forceRefresh}) => AnalyticsService
                    .instance
                    .getDashboard(forceRefresh: forceRefresh),
                isEmpty: (d) =>
                    d.kpi == null &&
                    d.pipeline.stages.isEmpty &&
                    (d.leadFunnel?.isEmpty ?? true),
                emptyBuilder: (context) => _buildAnalyticsEmpty(),
                builder: (context, data) => _buildAnalyticsSections(data),
              ),
              const SizedBox(height: AppSpacing.xl),

              // --- Immeubles (performance + aperçu des vacances) -----------
              _SectionLoader<List<BuildingItem>>(
                refreshTick: _refreshTick,
                skeleton: const _BuildingsSkeleton(),
                fetcher: _fetchBuildings,
                isEmpty: (b) => b.isEmpty,
                emptyBuilder: (context) => _buildBuildingsEmpty(),
                builder: (context, buildings) =>
                    _buildBuildingsSections(buildings),
              ),
              const SizedBox(height: AppSpacing.xl),

              // --- Activité récente ----------------------------------------
              _SectionLoader<List<CommunicationItem>>(
                refreshTick: _refreshTick,
                skeleton: const _ActivitySkeleton(),
                fetcher: ({required bool forceRefresh}) =>
                    CommunicationService.instance.getActivity(limit: 5),
                builder: (context, items) => _buildActivityFeed(items),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<BuildingItem>> _fetchBuildings(
      {required bool forceRefresh}) async {
    final response = await ApiService.instance.get('/buildings');
    final data = response['data'] as List<dynamic>;
    return data
        .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Widget _buildNewLeadCard() {
    return InkWell(
      onTap: () => Navigator.of(context).pushNamed('/leads'),
      borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.indigoDark],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Nouvelle piste',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        const Text('Période:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            _currentPeriodLabel(),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Analytics section (KPIs + funnel + pipeline + visits + inbox metrics)
  // ---------------------------------------------------------------------------

  Widget _buildAnalyticsSections(FullDashboardData data) {
    final children = <Widget>[];
    void add(Widget w) {
      if (children.isNotEmpty) children.add(const SizedBox(height: AppSpacing.xl));
      children.add(w);
    }

    if (data.kpi != null) add(_buildKpiCards(data.kpi!));
    if (data.leadFunnel != null && data.leadFunnel!.isNotEmpty) {
      add(LeadFunnelCard(funnelData: data.leadFunnel!));
    }
    if (data.pipeline.stages.isNotEmpty) add(_buildPipelineSection(data.pipeline));
    add(_buildVisitStatsSection(data.visitStats));
    if (data.inboxToVisitMetrics != null) {
      add(_buildInboxToVisitMetricsSection(data.inboxToVisitMetrics!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildAnalyticsEmpty() {
    return const EmptyState(
      title: 'Aucune donnée analytique',
      description:
          'Les indicateurs apparaîtront une fois les premiers baux et visites enregistrés.',
      icon: Icons.analytics_outlined,
      compact: true,
    );
  }

  Widget _buildKpiCards(KpiSummary kpi) {
    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          KpiCard(
            label: 'Revenus',
            value: _formatRevenue(kpi.revenue.current.toInt()),
            icon: Icons.attach_money,
            trendPercentage: kpi.revenue.trend,
            semanticLabel: 'Voir les paiements',
            onTap: () => Navigator.of(context).pushNamed('/payments'),
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: "Taux d'occupation",
            value: '${kpi.occupancyRate.current.toStringAsFixed(1)}%',
            icon: Icons.percent,
            trendPercentage: kpi.occupancyRate.trend,
            semanticLabel: "Voir les immeubles et le taux d'occupation",
            onTap: () => Navigator.of(context).pushNamed('/buildings'),
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: 'Baux actifs',
            value: '${kpi.activeLeases.current.toInt()}',
            icon: Icons.description,
            trendPercentage: kpi.activeLeases.trend,
            semanticLabel: 'Voir les baux actifs',
            onTap: () => Navigator.of(context).pushNamed('/leases'),
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: 'Pistes ouvertes',
            value: '${kpi.openLeads.current.toInt()}',
            icon: Icons.person_add,
            trendPercentage: kpi.openLeads.trend,
            semanticLabel: 'Voir les pistes ouvertes',
            onTap: () => Navigator.of(context).pushNamed('/leads'),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsSection(PillarsOverview pillars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Les 3 piliers', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            final leasingCard = _buildPillarCard(
              title: 'Leasing',
              icon: Icons.people_alt_outlined,
              accentColor: AppColors.primary,
              semanticLabel:
                  'Voir le leasing, ${pillars.leasing.activeLeads} pistes actives',
              onTap: () => Navigator.of(context).pushNamed('/leads'),
              metrics: [
                _PillarMetric('Pistes actives', '${pillars.leasing.activeLeads}'),
                _PillarMetric('Visites planifiées (sem.)', '${pillars.leasing.visitsThisWeek}'),
                _PillarMetric('Taux de conversion', pillars.leasing.conversionRate),
              ],
            );
            final maintenanceCard = _buildPillarCard(
              title: 'Maintenance',
              icon: Icons.build_outlined,
              accentColor: AppColors.skyBlue,
              semanticLabel:
                  'Voir la maintenance, ${pillars.maintenance.openTickets} tickets ouverts',
              onTap: () =>
                  Navigator.of(context).pushNamed('/maintenance-tickets'),
              metrics: [
                _PillarMetric('Tickets ouverts', '${pillars.maintenance.openTickets}'),
                _PillarMetric('En cours', '${pillars.maintenance.inProgressTickets}'),
                _PillarMetric(
                  'Résolution moy.',
                  pillars.maintenance.avgResolutionHours != null
                      ? '${pillars.maintenance.avgResolutionHours!.toStringAsFixed(1)} h'
                      : '—',
                ),
              ],
            );
            final renovationCard = _buildPillarCard(
              title: 'Rénovation',
              icon: Icons.handyman_outlined,
              accentColor: AppColors.warning,
              semanticLabel:
                  'Voir la rénovation, ${pillars.renovation.blockedProjects} projets bloqués',
              onTap: () => Navigator.of(context).pushNamed('/renovation-ops'),
              metrics: [
                _PillarMetric('Projets actifs', '${pillars.renovation.activeProjects}'),
                _PillarMetric('Bloqués', '${pillars.renovation.blockedProjects}'),
                _PillarMetric('Commandes ouvertes', '${pillars.renovation.openOrders}'),
              ],
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: leasingCard),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: maintenanceCard),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: renovationCard),
                ],
              );
            }

            return Column(
              children: [
                leasingCard,
                const SizedBox(height: AppSpacing.md),
                maintenanceCard,
                const SizedBox(height: AppSpacing.md),
                renovationCard,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPillarCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<_PillarMetric> metrics,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 22, color: accentColor),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(title, style: AppTypography.cardTitle),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                ...metrics.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              m.label,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          Text(
                            m.value,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineSection(PipelineData pipeline) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pipeline', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: pipeline.stages.entries.map((entry) {
            final stage = LeadStage.fromString(entry.key);
            final count = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: AppSpacing.cardDecoration(),
              child: Column(
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(stage.label, style: AppTypography.chartAxisLabel),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildVisitStatsSection(VisitStatsData vs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Statistiques des visites', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            _buildVisitStatChip(label: 'Total', value: vs.total, color: AppColors.textPrimary),
            const SizedBox(width: AppSpacing.sm),
            _buildVisitStatChip(label: 'Terminées', value: vs.completed, color: AppColors.success),
            const SizedBox(width: AppSpacing.sm),
            _buildVisitStatChip(label: 'Annulées', value: vs.cancelled, color: AppColors.error),
            const SizedBox(width: AppSpacing.sm),
            _buildVisitStatChip(label: 'Absent', value: vs.noShow, color: AppColors.warning),
          ],
        ),
      ],
    );
  }

  Widget _buildVisitStatChip({
    required String label,
    required int value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [AppSpacing.elevationCard],
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(label, style: AppTypography.chartAxisLabel),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxToVisitMetricsSection(InboxToVisitMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Flux inbox → visite', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 720;
            final dailyCard = Expanded(
              child: _buildOperationalMetricsCard(
                title: '24 dernières heures',
                subtitle: 'Vue quotidienne',
                metrics: metrics.daily,
                accentColor: AppColors.primary,
              ),
            );
            final weeklyCard = Expanded(
              child: _buildOperationalMetricsCard(
                title: '7 derniers jours',
                subtitle: 'Vue hebdomadaire',
                metrics: metrics.weekly,
                accentColor: AppColors.skyBlue,
              ),
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  dailyCard,
                  const SizedBox(width: AppSpacing.md),
                  weeklyCard,
                ],
              );
            }

            return Column(
              children: [
                _buildOperationalMetricsCard(
                  title: '24 dernières heures',
                  subtitle: 'Vue quotidienne',
                  metrics: metrics.daily,
                  accentColor: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildOperationalMetricsCard(
                  title: '7 derniers jours',
                  subtitle: 'Vue hebdomadaire',
                  metrics: metrics.weekly,
                  accentColor: AppColors.skyBlue,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOperationalMetricsCard({
    required String title,
    required String subtitle,
    required OperationalMetricsWindow metrics,
    required Color accentColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.cardTitle),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _buildOperationalMetricTile(
                label: 'Volume boîte',
                value: metrics.inboxVolume,
                color: AppColors.primary,
                icon: Icons.inbox_outlined,
              ),
              _buildOperationalMetricTile(
                label: 'Réponses',
                value: metrics.replies,
                color: AppColors.info,
                icon: Icons.reply_outlined,
              ),
              _buildOperationalMetricTile(
                label: 'Réservations',
                value: metrics.bookings,
                color: AppColors.skyBlue,
                icon: Icons.event_available_outlined,
              ),
              _buildOperationalMetricTile(
                label: 'Terminées',
                value: metrics.completedVisits,
                color: AppColors.success,
                icon: Icons.check_circle_outline,
              ),
              _buildOperationalMetricTile(
                label: 'No-shows',
                value: metrics.noShows,
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
              _buildOperationalMetricTile(
                label: 'Bloquées',
                value: metrics.stalledConversations,
                color: AppColors.warning,
                icon: Icons.hourglass_bottom_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalMetricTile({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Buildings section (performance + vacancy summary)
  // ---------------------------------------------------------------------------

  Widget _buildBuildingsSections(List<BuildingItem> buildings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BuildingPerformanceCard(
          buildings: buildings,
          onViewAll: () {
            Navigator.of(context).pushNamed('/buildings');
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildVacancySummary(context, buildings),
      ],
    );
  }

  Widget _buildBuildingsEmpty() {
    return EmptyState(
      title: 'Aucun immeuble',
      description:
          'Ajoutez votre premier immeuble pour suivre l’occupation et les vacances.',
      icon: Icons.apartment_outlined,
      ctaLabel: 'Ajouter un immeuble',
      ctaIcon: Icons.add,
      onCtaPressed: () => Navigator.of(context).pushNamed('/buildings'),
    );
  }

  Widget _buildActivityFeed(List<CommunicationItem> recentCommunications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Activité récente', style: AppTypography.sectionHeader),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed('/communications');
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
        if (recentCommunications.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Aucune activité récente', style: AppTypography.caption),
            ),
          )
        else
          ...recentCommunications.map((item) {
            final typeColor = _communicationTypeColor(item.type);
            final typeIcon = _communicationTypeIcon(item.type);
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(14),
              decoration: AppSpacing.cardDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(typeIcon, size: 20, color: typeColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_communicationTypeLabel(item.type)}: ${item.contactName}',
                          style: AppTypography.cardTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.body.isNotEmpty ? item.body : item.subject,
                          style: AppTypography.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatTimeAgo(item.createdAt),
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Color _communicationTypeColor(String type) {
    switch (type) {
      case 'sms':
        return AppColors.funnelContacte;
      case 'email':
        return AppColors.info;
      case 'call':
        return AppColors.success;
      default:
        return AppColors.warning;
    }
  }

  IconData _communicationTypeIcon(String type) {
    switch (type) {
      case 'sms':
        return Icons.sms_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'call':
        return Icons.phone_outlined;
      default:
        return Icons.note_outlined;
    }
  }

  String _communicationTypeLabel(String type) {
    switch (type) {
      case 'sms':
        return 'SMS';
      case 'email':
        return 'Courriel';
      case 'call':
        return 'Appel';
      default:
        return 'Note';
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return DateFormat('d MMM').format(dt);
  }

  Widget _buildVacancySummary(BuildContext context, List<BuildingItem> buildings) {
    int totalUnits = 0;
    int occupiedUnits = 0;
    int vacantUnits = 0;
    for (final b in buildings) {
      totalUnits += b.totalUnits;
      occupiedUnits += b.occupiedUnits;
      vacantUnits += b.totalUnits - b.occupiedUnits;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.door_front_door, color: AppColors.primary, size: 20),
              SizedBox(width: AppSpacing.sm),
              Text('Aperçu des vacances', style: AppTypography.sectionHeader),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildVacancyChip(label: 'Total', count: totalUnits, color: AppColors.textPrimary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildVacancyChip(label: 'Occupées', count: occupiedUnits, color: AppColors.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildVacancyChip(label: 'Libres', count: vacantUnits, color: AppColors.warning),
              ),
            ],
          ),
          if (buildings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const UnitsScreen()),
                  );
                },
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Voir toutes les unités'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVacancyChip({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarMetric {
  const _PillarMetric(this.label, this.value);
  final String label;
  final String value;
}

// =============================================================================
// Generic per-section loader
// =============================================================================

typedef _SectionFetcher<T> = Future<T> Function({required bool forceRefresh});

/// Loads one dashboard section independently: shows its own skeleton while
/// loading, its own [ErrorState] (with a working retry that re-hits the
/// network) on failure, an optional empty state, otherwise the built content.
///
/// A failure in one section never blocks the others.
class _SectionLoader<T> extends StatefulWidget {
  const _SectionLoader({
    super.key,
    required this.fetcher,
    required this.builder,
    required this.skeleton,
    required this.refreshTick,
    this.isEmpty,
    this.emptyBuilder,
  });

  final _SectionFetcher<T> fetcher;
  final Widget Function(BuildContext context, T data) builder;
  final Widget skeleton;

  /// Bumped by the parent on pull-to-refresh to trigger an independent reload.
  final ValueListenable<int> refreshTick;

  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;

  @override
  State<_SectionLoader<T>> createState() => _SectionLoaderState<T>();
}

class _SectionLoaderState<T> extends State<_SectionLoader<T>> {
  bool _loading = true;
  Object? _error;
  T? _data;

  /// Guards against out-of-order responses when retries overlap.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshTick.addListener(_onRefreshTick);
    _load(forceRefresh: false);
  }

  @override
  void dispose() {
    widget.refreshTick.removeListener(_onRefreshTick);
    super.dispose();
  }

  void _onRefreshTick() => _load(forceRefresh: true);

  Future<void> _load({required bool forceRefresh}) async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.fetcher(forceRefresh: forceRefresh);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.skeleton;

    if (_error != null) {
      return ErrorState(
        error: _error!,
        compact: true,
        onRetry: () => _load(forceRefresh: true),
      );
    }

    final data = _data as T;
    if (widget.isEmpty?.call(data) ?? false) {
      return widget.emptyBuilder?.call(context) ?? const SizedBox.shrink();
    }
    return widget.builder(context, data);
  }
}

// =============================================================================
// Per-section skeletons
// =============================================================================

class _PillarsSkeleton extends StatelessWidget {
  const _PillarsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerBox(width: 120, height: 18, radius: 6),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 720) {
              return const Row(
                children: [
                  Expanded(child: ShimmerBox(height: 168)),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: ShimmerBox(height: 168)),
                  SizedBox(width: AppSpacing.md),
                  Expanded(child: ShimmerBox(height: 168)),
                ],
              );
            }
            return const Column(
              children: [
                ShimmerBox(width: double.infinity, height: 168),
                SizedBox(height: AppSpacing.md),
                ShimmerBox(width: double.infinity, height: 168),
                SizedBox(height: AppSpacing.md),
                ShimmerBox(width: double.infinity, height: 168),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  const _AnalyticsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const [
              ShimmerBox(width: 160, height: 130),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 160, height: 130),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 160, height: 130),
              SizedBox(width: AppSpacing.sm),
              ShimmerBox(width: 160, height: 130),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        const ShimmerBox(width: double.infinity, height: 180),
      ],
    );
  }
}

class _BuildingsSkeleton extends StatelessWidget {
  const _BuildingsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: double.infinity, height: 200),
        SizedBox(height: AppSpacing.xl),
        ShimmerBox(width: double.infinity, height: 140),
      ],
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerBox(width: 140, height: 18, radius: 6),
        const SizedBox(height: AppSpacing.md),
        ...List.generate(
          3,
          (i) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SkeletonRow(height: 56),
          ),
        ),
      ],
    );
  }
}
