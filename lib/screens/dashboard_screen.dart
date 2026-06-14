import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  FullDashboardData? _dashboardData;
  PillarsOverview? _pillars;
  List<BuildingItem> _buildings = [];
  List<CommunicationItem> _recentCommunications = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        AnalyticsService.instance.getDashboard(),
        AnalyticsService.instance.getPillarsOverview(),
        ApiService.instance.get('/buildings'),
        CommunicationService.instance.getActivity(limit: 5),
      ]);

      final analytics = results[0] as FullDashboardData;
      final pillars = results[1] as PillarsOverview;
      final buildingsResponse = results[2];
      final communications = results[3] as List<CommunicationItem>;

      final buildingsData = (buildingsResponse as Map<String, dynamic>)['data'] as List<dynamic>;

      setState(() {
        _dashboardData = analytics;
        _pillars = pillars;
        _buildings = buildingsData
            .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _recentCommunications = communications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _currentPeriodLabel() {
    final now = DateTime.now();
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  KpiSummary? get _kpi => _dashboardData?.kpi;

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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'quick_actions_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
        onPressed: () {
          Navigator.of(context).pushNamed('/communications');
        },
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('Nouvelle piste', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
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
                'Erreur de chargement',
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
              onPressed: _fetchDashboard,
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

    final hasNoData = _kpi == null &&
        _buildings.isEmpty &&
        (_dashboardData?.pipeline.stages.isEmpty ?? true);

    if (hasNoData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Aucune donnée disponible',
              style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Les données apparaîtront une fois les premiers baux et immeubles ajoutés.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/buildings');
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Ajouter un immeuble'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: AppSpacing.xl),

            if (_pillars != null) ...[
              _buildPillarsSection(),
              const SizedBox(height: AppSpacing.xl),
            ],

            _buildKpiCards(),
            const SizedBox(height: AppSpacing.xl),

            if (_dashboardData?.leadFunnel != null &&
                (_dashboardData!.leadFunnel!.isNotEmpty))
              LeadFunnelCard(funnelData: _dashboardData!.leadFunnel!),
            if (_dashboardData?.leadFunnel != null &&
                _dashboardData!.leadFunnel!.isNotEmpty)
              const SizedBox(height: AppSpacing.xl),

            if (_dashboardData?.pipeline.stages.isNotEmpty == true) ...[
              _buildPipelineSection(),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (_dashboardData?.visitStats != null) ...[
              _buildVisitStatsSection(),
              const SizedBox(height: AppSpacing.xl),
            ],

            if (_dashboardData?.inboxToVisitMetrics != null) ...[
              _buildInboxToVisitMetricsSection(),
              const SizedBox(height: AppSpacing.xl),
            ],

            BuildingPerformanceCard(
              buildings: _buildings,
              onViewAll: () {
                Navigator.of(context).pushNamed('/buildings');
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            _buildActivityFeed(),
            const SizedBox(height: AppSpacing.xl),

            _buildVacancySummary(context),
            const SizedBox(height: 24),
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

  Widget _buildKpiCards() {
    if (_kpi == null) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          KpiCard(
            label: 'Revenus',
            value: _formatRevenue(_kpi!.revenue.current.toInt()),
            icon: Icons.attach_money,
            trendPercentage: _kpi!.revenue.trend,
            onTap: () {},
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: "Taux d'occupation",
            value: '${_kpi!.occupancyRate.current.toStringAsFixed(1)}%',
            icon: Icons.percent,
            trendPercentage: _kpi!.occupancyRate.trend,
            onTap: () {},
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: 'Baux actifs',
            value: '${_kpi!.activeLeases.current.toInt()}',
            icon: Icons.description,
            trendPercentage: _kpi!.activeLeases.trend,
            onTap: () {
              Navigator.of(context).pushNamed('/leases');
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          KpiCard(
            label: 'Pistes ouvertes',
            value: '${_kpi!.openLeads.current.toInt()}',
            icon: Icons.person_add,
            trendPercentage: _kpi!.openLeads.trend,
            onTap: () {
              Navigator.of(context).pushNamed('/communications');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsSection() {
    final pillars = _pillars!;
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
              onTap: () => Navigator.of(context).pushNamed('/leads'),
              metrics: [
                _PillarMetric('Pistes actives', '${pillars.leasing.activeLeads}'),
                _PillarMetric('Visites cette semaine', '${pillars.leasing.visitsThisWeek}'),
                _PillarMetric('Taux de conversion', pillars.leasing.conversionRate),
              ],
            );
            final maintenanceCard = _buildPillarCard(
              title: 'Maintenance',
              icon: Icons.build_outlined,
              accentColor: AppColors.skyBlue,
              onTap: () => Navigator.of(context).pushNamed('/maintenance-tickets'),
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
  }) {
    return Card(
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
    );
  }

  Widget _buildPipelineSection() {
    final pipeline = _dashboardData!.pipeline;
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

  Widget _buildVisitStatsSection() {
    final vs = _dashboardData!.visitStats;
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

  Widget _buildInboxToVisitMetricsSection() {
    final metrics = _dashboardData!.inboxToVisitMetrics!;
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

  Widget _buildActivityFeed() {
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
        if (_recentCommunications.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('Aucune activité récente', style: AppTypography.caption),
            ),
          )
        else
          ..._recentCommunications.map((item) {
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

  Widget _buildVacancySummary(BuildContext context) {
    int totalUnits = 0;
    int occupiedUnits = 0;
    int vacantUnits = 0;
    for (final b in _buildings) {
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
          if (_buildings.isNotEmpty) ...[
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
