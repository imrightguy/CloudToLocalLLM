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
import '../widgets/occupancy_chart.dart';
import '../widgets/revenue_chart.dart';
import 'units_screen.dart';
import 'onboarding_screen.dart';
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
        ApiService.instance.get('/buildings'),
        CommunicationService.instance.getActivity(limit: 5),
      ]);

      final analytics = results[0] as FullDashboardData;
      final buildingsResponse = results[1];
      final communications = results[2] as List<CommunicationItem>;

      final buildingsData = (buildingsResponse as Map<String, dynamic>)['data'] as List<dynamic>;

      setState(() {
        _dashboardData = analytics;
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
      appBar: ImmoAppBar(title: 'Tableau de bord'),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'quick_actions_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const StadiumBorder(),
        onPressed: () {
          Navigator.of(context).pushNamed('/pipeline');
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
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Configuration initiale guidée'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    final revenueChart = _dashboardData?.revenueChart
            ?.map((e) => RevenueDataPoint.fromJson(e))
            .toList() ??
        [];
    final occupancyChart = _dashboardData?.occupancyChart
            ?.map((e) => OccupancyDataPoint.fromJson(e))
            .toList() ??
        [];

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

            _buildKpiCards(),
            const SizedBox(height: AppSpacing.xl),

            RevenueChartCard(data: revenueChart),
            const SizedBox(height: AppSpacing.xl),

            OccupancyChartCard(
              data: occupancyChart,
              currentRate: _kpi?.occupancyRate.current.toDouble(),
            ),
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
            color: AppColors.primary.withOpacity( 0.1),
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
              Navigator.of(context).pushNamed('/pipeline');
            },
          ),
        ],
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
                child: Text(
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
                      color: typeColor.withOpacity( 0.1),
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
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
        color: color.withOpacity( 0.1),
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
              color: color.withOpacity( 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
