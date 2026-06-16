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
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';
import '../widgets/empty_state.dart';

/// French weekday names, indexed by `DateTime.weekday - 1` (1 = Monday).
const List<String> _kFrenchWeekdays = [
  'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
];

/// Cockpit dashboard answering "qu'est-ce qui demande mon attention aujourd'hui ?".
///
/// Five stacked sections, each loading/refreshing **independently** so a failure
/// in one never blocks the others:
///   1. Personalised header + quick-action shortcuts
///   2. « À traiter » action banner (top visual priority)  — from pillars
///   3. The three pillars (clickable)                       — from pillars
///   4. Recent activity feed                                — from communications
///   5. Portfolio overview                                  — from buildings
///
/// Each data source uses the direct-call pattern (fetch in [initState], own
/// loading/error/data fields, retry that re-hits only that source). The pillars
/// fetch feeds both section 2 and section 3.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- Pillars (drives « À traiter » + the 3 pillars) ------------------------
  PillarsOverview? _pillars;
  bool _pillarsLoading = true;
  Object? _pillarsError;

  // --- Recent activity -------------------------------------------------------
  List<CommunicationItem>? _activity;
  bool _activityLoading = true;
  Object? _activityError;

  // --- Buildings / portfolio -------------------------------------------------
  List<BuildingItem>? _buildings;
  bool _buildingsLoading = true;
  Object? _buildingsError;

  @override
  void initState() {
    super.initState();
    _fetchPillars();
    _fetchActivity();
    _fetchBuildings();
  }

  Future<void> _fetchPillars({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _pillarsLoading = true;
      _pillarsError = null;
    });
    try {
      final pillars = await AnalyticsService.instance
          .getPillarsOverview(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _pillars = pillars;
        _pillarsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pillarsError = e;
        _pillarsLoading = false;
      });
    }
  }

  Future<void> _fetchActivity({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _activityLoading = true;
      _activityError = null;
    });
    try {
      final items = await CommunicationService.instance.getActivity(limit: 5);
      if (!mounted) return;
      setState(() {
        _activity = items;
        _activityLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _activityError = e;
        _activityLoading = false;
      });
    }
  }

  Future<void> _fetchBuildings({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _buildingsLoading = true;
      _buildingsError = null;
    });
    try {
      final response = await ApiService.instance.get('/buildings');
      final data = response['data'] as List<dynamic>;
      final buildings = data
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _buildings = buildings;
        _buildingsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _buildingsError = e;
        _buildingsLoading = false;
      });
    }
  }

  /// Pull-to-refresh: force-reload every section in parallel.
  Future<void> _handleRefresh() async {
    await Future.wait([
      _fetchPillars(forceRefresh: true),
      _fetchActivity(forceRefresh: true),
      _fetchBuildings(forceRefresh: true),
    ]);
  }

  void _go(String route) => Navigator.of(context).pushNamed(route);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Tableau de bord',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Rafraîchir',
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Piliers FIXES — hors SingleChildScrollView pour garantir le hit testing
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: _buildPillarsBlock(),
          ),
          // Reste du contenu dans le scroll view
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl + 32,
              ),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildAttentionBlock(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildActivityBlock(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildPortfolioBlock(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 1. Header
  // ===========================================================================

  Widget _buildHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 18 ? 'Bonjour' : 'Bonsoir';
    final dateLabel =
        '${_kFrenchWeekdays[now.weekday - 1]} ${now.day} '
        '${kFrenchMonths[now.month - 1].toLowerCase()} ${now.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting Simon', style: AppTypography.pageTitle),
        const SizedBox(height: 4),
        Text(dateLabel, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _buildQuickAction(
              icon: Icons.person_add_alt_1_outlined,
              label: 'Nouvelle piste',
              route: '/leads',
            ),
            _buildQuickAction(
              icon: Icons.build_outlined,
              label: 'Ticket maintenance',
              route: '/maintenance-tickets',
            ),
            _buildQuickAction(
              icon: Icons.handyman_outlined,
              label: 'Projet rénovation',
              route: '/renovation-ops',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required String route,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        child: InkWell(
          onTap: () => _go(route),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. « À traiter » banner (pillars-driven)
  // ===========================================================================

  Widget _buildAttentionBlock() {
    if (_pillarsLoading) return const _AttentionSkeleton();
    if (_pillarsError != null) {
      return _SectionFrame(
        title: 'À traiter',
        child: ErrorState(
          error: _pillarsError!,
          compact: true,
          onRetry: () => _fetchPillars(forceRefresh: true),
        ),
      );
    }
    return _buildAttentionBanner(_pillars!);
  }

  Widget _buildAttentionBanner(PillarsOverview p) {
    // Ordered by visual priority: blocked (red) → to-do (orange) → info (blue).
    final items = <_AttentionItem>[
      _AttentionItem(
        icon: Icons.report_problem_outlined,
        label: 'Projets de rénovation bloqués',
        count: p.renovation.blockedProjects,
        color: AppColors.error,
        route: '/renovation-ops',
      ),
      _AttentionItem(
        icon: Icons.build_outlined,
        label: 'Tickets de maintenance ouverts',
        count: p.maintenance.openTickets,
        color: AppColors.warning,
        route: '/maintenance-tickets',
      ),
      _AttentionItem(
        icon: Icons.receipt_long_outlined,
        label: 'Commandes ouvertes',
        count: p.renovation.openOrders,
        color: AppColors.warning,
        route: '/renovation-ops',
      ),
      _AttentionItem(
        icon: Icons.event_outlined,
        label: 'Visites planifiées cette semaine',
        count: p.leasing.visitsThisWeek,
        color: AppColors.primary,
        route: '/leads',
      ),
      _AttentionItem(
        icon: Icons.people_alt_outlined,
        label: 'Pistes actives',
        count: p.leasing.activeLeads,
        color: AppColors.primary,
        route: '/leads',
      ),
    ].where((i) => i.count > 0).toList();

    final totalToTreat = items.fold<int>(0, (sum, i) => sum + i.count);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        border: Border.all(
          color: items.isEmpty
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.flag_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                const Text('À traiter', style: AppTypography.sectionHeader),
                const Spacer(),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '$totalToTreat',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (items.isEmpty)
            _buildAllClear()
          else
            ...List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  if (i == 0)
                    const Divider(height: 1, color: AppColors.border),
                  _buildAttentionRow(item),
                  if (i < items.length - 1)
                    const Divider(height: 1, color: AppColors.border),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAttentionRow(_AttentionItem item) {
    return Semantics(
      button: true,
      label: '${item.label}: ${item.count}',
      child: InkWell(
        onTap: () => _go(item.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, size: 19, color: item.color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  item.label,
                  style: AppTypography.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${item.count}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllClear() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline,
                size: 22, color: AppColors.success),
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Text(
              'Tout est à jour ✓',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. The three pillars (pillars-driven)
  // ===========================================================================

  Widget _buildPillarsBlock() {
    if (_pillarsLoading) return const _PillarsSkeleton();
    if (_pillarsError != null) {
      return _SectionFrame(
        title: 'Les 3 piliers',
        child: ErrorState(
          error: _pillarsError!,
          compact: true,
          onRetry: () => _fetchPillars(forceRefresh: true),
        ),
      );
    }
    return _buildPillarsSection(_pillars!);
  }

  Widget _buildPillarsSection(PillarsOverview pillars) {
    final isWide = MediaQuery.of(context).size.width > 720;

    Widget buildCard(String title, IconData icon, Color accentColor,
        List<_PillarMetric> metrics, String route) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.all(AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(color: AppColors.border.withValues(alpha: 0.4)),
          ),
          elevation: 0,
        ),
        onPressed: () => Navigator.of(context).pushNamed(route),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 22, color: accentColor)),
              const SizedBox(width: AppSpacing.md),
              Text(title, style: AppTypography.cardTitle),
              const SizedBox(width: AppSpacing.sm),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ]),
            const SizedBox(height: AppSpacing.lg),
            ...metrics.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(m.label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.sm),
                Text(m.value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accentColor)),
              ]))),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Les 3 piliers', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        if (isWide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Flexible(child: buildCard('Leasing', Icons.people_alt_outlined, AppColors.primary, [
              _PillarMetric('Pistes actives', '${pillars.leasing.activeLeads}'),
              _PillarMetric('Visites planifiées (sem.)', '${pillars.leasing.visitsThisWeek}'),
              _PillarMetric('Taux de conversion', pillars.leasing.conversionRate),
            ], '/leads')),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: buildCard('Maintenance', Icons.build_outlined, AppColors.skyBlue, [
              _PillarMetric('Tickets ouverts', '${pillars.maintenance.openTickets}'),
              _PillarMetric('En cours', '${pillars.maintenance.inProgressTickets}'),
              _PillarMetric('Résolution moy.', pillars.maintenance.avgResolutionHours != null ? '${pillars.maintenance.avgResolutionHours!.toStringAsFixed(1)} h' : '—'),
            ], '/maintenance-tickets')),
            const SizedBox(width: AppSpacing.md),
            Flexible(child: buildCard('Rénovation', Icons.handyman_outlined, AppColors.warning, [
              _PillarMetric('Projets actifs', '${pillars.renovation.activeProjects}'),
              _PillarMetric('Bloqués', '${pillars.renovation.blockedProjects}'),
              _PillarMetric('Commandes ouvertes', '${pillars.renovation.openOrders}'),
            ], '/renovation-ops')),
          ])
        else
          Column(children: [
            buildCard('Leasing', Icons.people_alt_outlined, AppColors.primary, [
              _PillarMetric('Pistes actives', '${pillars.leasing.activeLeads}'),
              _PillarMetric('Visites planifiées (sem.)', '${pillars.leasing.visitsThisWeek}'),
              _PillarMetric('Taux de conversion', pillars.leasing.conversionRate),
            ], '/leads'),
            const SizedBox(height: AppSpacing.md),
            buildCard('Maintenance', Icons.build_outlined, AppColors.skyBlue, [
              _PillarMetric('Tickets ouverts', '${pillars.maintenance.openTickets}'),
              _PillarMetric('En cours', '${pillars.maintenance.inProgressTickets}'),
              _PillarMetric('Résolution moy.', pillars.maintenance.avgResolutionHours != null ? '${pillars.maintenance.avgResolutionHours!.toStringAsFixed(1)} h' : '—'),
            ], '/maintenance-tickets'),
            const SizedBox(height: AppSpacing.md),
            buildCard('Rénovation', Icons.handyman_outlined, AppColors.warning, [
              _PillarMetric('Projets actifs', '${pillars.renovation.activeProjects}'),
              _PillarMetric('Bloqués', '${pillars.renovation.blockedProjects}'),
              _PillarMetric('Commandes ouvertes', '${pillars.renovation.openOrders}'),
            ], '/renovation-ops'),
          ]),
      ],
    );
  }

  // ===========================================================================
  // 4. Recent activity (communications-driven)
  // ===========================================================================

  Widget _buildActivityBlock() {
    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Activité récente', style: AppTypography.sectionHeader),
          GestureDetector(
            onTap: () => _go('/communications'),
            child: const Text(
              'Voir tout',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );

    Widget body;
    if (_activityLoading) {
      body = const _ActivityListSkeleton();
    } else if (_activityError != null) {
      body = ErrorState(
        error: _activityError!,
        compact: true,
        onRetry: () => _fetchActivity(forceRefresh: true),
      );
    } else if ((_activity ?? const []).isEmpty) {
      body = const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Aucune activité récente', style: AppTypography.caption),
        ),
      );
    } else {
      body = Column(
        children: _activity!.map(_buildActivityRow).toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [header, body],
    );
  }

  Widget _buildActivityRow(CommunicationItem item) {
    final typeColor = _communicationTypeColor(item.type);
    final typeIcon = _communicationTypeIcon(item.type);
    final description = item.body.isNotEmpty ? item.body : item.subject;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppSpacing.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        child: InkWell(
          onTap: () => _go('/communications'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                        description,
                        style: AppTypography.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _formatTimeAgo(item.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
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
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
    return DateFormat('d MMM').format(dt);
  }

  // ===========================================================================
  // 5. Portfolio overview (buildings-driven)
  // ===========================================================================

  Widget _buildPortfolioBlock() {
    if (_buildingsLoading) return const _PortfolioSkeleton();
    if (_buildingsError != null) {
      return _SectionFrame(
        title: 'Aperçu du portefeuille',
        child: ErrorState(
          error: _buildingsError!,
          compact: true,
          onRetry: () => _fetchBuildings(forceRefresh: true),
        ),
      );
    }
    final buildings = _buildings ?? const <BuildingItem>[];
    if (buildings.isEmpty) {
      return _SectionFrame(
        title: 'Aperçu du portefeuille',
        child: EmptyState(
          title: 'Aucun immeuble',
          description:
              'Ajoutez votre premier immeuble pour suivre l’occupation et les vacances.',
          icon: Icons.apartment_outlined,
          ctaLabel: 'Ajouter un immeuble',
          ctaIcon: Icons.add,
          onCtaPressed: () => _go('/buildings'),
        ),
      );
    }
    return _buildPortfolioSummary(buildings);
  }

  Widget _buildPortfolioSummary(List<BuildingItem> buildings) {
    int totalUnits = 0;
    int occupiedUnits = 0;
    for (final b in buildings) {
      totalUnits += b.totalUnits;
      occupiedUnits += b.occupiedUnits;
    }
    final vacantUnits = totalUnits - occupiedUnits;
    final occupancyRate =
        totalUnits > 0 ? (occupiedUnits / totalUnits) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aperçu du portefeuille', style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: AppSpacing.cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.apartment_outlined,
                        size: 22, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${buildings.length} '
                      '${buildings.length > 1 ? 'immeubles' : 'immeuble'}',
                      style: AppTypography.cardTitle,
                    ),
                  ),
                  Text(
                    '${occupancyRate.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Padding(
                padding: EdgeInsets.only(left: 52),
                child: Text("Taux d'occupation global",
                    style: AppTypography.caption),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: _buildPortfolioStat(
                        label: 'Unités', count: totalUnits,
                        color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildPortfolioStat(
                        label: 'Occupées', count: occupiedUnits,
                        color: AppColors.success),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildPortfolioStat(
                        label: 'Libres', count: vacantUnits,
                        color: AppColors.warning),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _go('/buildings'),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Voir tous les immeubles'),
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
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioStat({
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

// =============================================================================
// Small models
// =============================================================================

class _PillarMetric {
  const _PillarMetric(this.label, this.value);
  final String label;
  final String value;
}

class _AttentionItem {
  const _AttentionItem({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.route,
  });
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final String route;
}

// =============================================================================
// Shared layout helper
// =============================================================================

/// Wraps a section header above an error/empty/placeholder body so a failing
/// section keeps its title and visual footprint.
class _SectionFrame extends StatelessWidget {
  const _SectionFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.md),
        child,
      ],
    );
  }
}

// =============================================================================
// Per-section skeletons
// =============================================================================

class _AttentionSkeleton extends StatelessWidget {
  const _AttentionSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 120, height: 18, radius: 6),
        SizedBox(height: AppSpacing.md),
        ShimmerBox(width: double.infinity, height: 180),
      ],
    );
  }
}

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

class _ActivityListSkeleton extends StatelessWidget {
  const _ActivityListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        3,
        (i) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: SkeletonRow(height: 56),
        ),
      ),
    );
  }
}

class _PortfolioSkeleton extends StatelessWidget {
  const _PortfolioSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShimmerBox(width: 180, height: 18, radius: 6),
        SizedBox(height: AppSpacing.md),
        ShimmerBox(width: double.infinity, height: 200),
      ],
    );
  }
}
