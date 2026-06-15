import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/maintenance_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';

/// Mode de tri de la liste des propriétés.
enum _SortMode { overdue, dueDate, name }

/// Filtre appliqué à la liste des propriétés. Peut être déclenché par un KPI
/// prioritaire (overdue / blocked / intake / ready) ou par les filtres rapides
/// (all / actionNeeded / blocked).
enum _MaintenanceFilter { all, actionNeeded, overdue, blocked, intake, ready }

String _filterLabel(_MaintenanceFilter filter) {
  switch (filter) {
    case _MaintenanceFilter.all:
      return 'Tout';
    case _MaintenanceFilter.actionNeeded:
      return 'À traiter';
    case _MaintenanceFilter.overdue:
      return 'Tâches en retard';
    case _MaintenanceFilter.blocked:
      return 'Bloqués';
    case _MaintenanceFilter.intake:
      return 'Demandes en cours';
    case _MaintenanceFilter.ready:
      return 'Tâches prêtes';
  }
}

bool _matchesFilter(
  MaintenanceCommandCenterProperty property,
  _MaintenanceFilter filter,
) {
  switch (filter) {
    case _MaintenanceFilter.all:
      return true;
    case _MaintenanceFilter.actionNeeded:
      return property.overdueTaskCount > 0 || property.blockedCount > 0;
    case _MaintenanceFilter.overdue:
      return property.overdueTaskCount > 0;
    case _MaintenanceFilter.blocked:
      return property.blockedCount > 0;
    case _MaintenanceFilter.intake:
      return property.pendingIntakeCount > 0;
    case _MaintenanceFilter.ready:
      return property.capacity.dispatchableCount > 0;
  }
}

class MaintenanceCommandCenterScreen extends StatefulWidget {
  const MaintenanceCommandCenterScreen({super.key});

  @override
  State<MaintenanceCommandCenterScreen> createState() =>
      _MaintenanceCommandCenterScreenState();
}

class _MaintenanceCommandCenterScreenState
    extends State<MaintenanceCommandCenterScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MaintenanceCommandCenterData _data = _emptyData();
  List<BuildingTicketCount> _ticketCountsByBuilding = const [];

  final TextEditingController _searchController = TextEditingController();
  _SortMode _sortMode = _SortMode.overdue;
  _MaintenanceFilter _filter = _MaintenanceFilter.all;

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
      final counts = results[1] as List<BuildingTicketCount>;
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
        _ticketCountsByBuilding = const [];
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<BuildingTicketCount>> _fetchTicketCounts() async {
    try {
      return await MaintenanceService.instance.getOpenTicketCountByBuilding();
    } catch (_) {
      return const [];
    }
  }

  bool get _hasNoData => _data.isEmpty;

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return DateFormat('d MMM HH:mm', 'fr').format(dateTime.toLocal());
  }

  String _formatDateOnly(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return DateFormat('d MMM', 'fr').format(dateTime.toLocal());
  }

  /// Propriétés après recherche, filtre et tri.
  List<MaintenanceCommandCenterProperty> get _visibleProperties {
    final query = _searchController.text.trim().toLowerCase();
    final list = _data.properties.where((property) {
      if (!_matchesFilter(property, _filter)) return false;
      if (query.isNotEmpty &&
          !property.buildingName.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      switch (_sortMode) {
        case _SortMode.overdue:
          final byOverdue = b.overdueTaskCount.compareTo(a.overdueTaskCount);
          if (byOverdue != 0) return byOverdue;
          final byBlocked = b.blockedCount.compareTo(a.blockedCount);
          if (byBlocked != 0) return byBlocked;
          return a.buildingName
              .toLowerCase()
              .compareTo(b.buildingName.toLowerCase());
        case _SortMode.dueDate:
          final ad = a.nextDueAt;
          final bd = b.nextDueAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        case _SortMode.name:
          return a.buildingName
              .toLowerCase()
              .compareTo(b.buildingName.toLowerCase());
      }
    });
    return list;
  }

  void _toggleFilter(_MaintenanceFilter filter) {
    setState(() {
      _filter = _filter == filter ? _MaintenanceFilter.all : filter;
    });
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const ListSkeleton(itemCount: 5);
    }

    // Échec total du chargement, sans données à afficher.
    if (_errorMessage != null && _hasNoData) {
      return ErrorState(
        error: _errorMessage!,
        onRetry: _fetchCommandCenter,
        title: 'Maintenance indisponible',
      );
    }

    // Aucune donnée mais pas d'erreur : état vide pleine page.
    if (_hasNoData) {
      return _refreshable(
        child: const EmptyState(
          icon: Icons.construction_outlined,
          title: 'Aucune donnée de maintenance',
          description:
              'Le tableau de bord s’affichera dès qu’il y aura des rénovations, '
              'des équipes ou des messages locataires à suivre.',
        ),
        fillViewport: true,
      );
    }

    final visible = _visibleProperties;

    return _refreshable(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderSummary(
              asOf: _data.asOf,
              propertyCount: _data.summary.propertyCount,
              degraded: _errorMessage != null,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.xl),

            // 1 + 2 — KPIs prioritaires, sémantiques et cliquables.
            _PriorityKpis(
              summary: _data.summary,
              filter: _filter,
              onTap: _toggleFilter,
            ),
            const SizedBox(height: AppSpacing.md),
            _SecondaryKpis(summary: _data.summary),
            const SizedBox(height: AppSpacing.xl),

            // 4 — Recherche, tri, filtres rapides.
            const _SectionHeader(
              title: 'Propriétés',
              subtitle:
                  'Recherchez, triez et filtrez les immeubles qui nécessitent '
                  'une intervention.',
            ),
            const SizedBox(height: AppSpacing.md),
            _Toolbar(
              searchController: _searchController,
              sortMode: _sortMode,
              filter: _filter,
              onSearchChanged: (_) => setState(() {}),
              onSortChanged: (mode) => setState(() => _sortMode = mode),
              onFilterChanged: (filter) => setState(() => _filter = filter),
            ),
            if (_filter != _MaintenanceFilter.all) ...[
              const SizedBox(height: AppSpacing.md),
              _ActiveFilterChip(
                label: _filterLabel(_filter),
                onClear: () =>
                    setState(() => _filter = _MaintenanceFilter.all),
              ),
            ],
            const SizedBox(height: AppSpacing.md),

            // 3 + 6 — Cartes de propriétés repliables / état vide.
            if (visible.isEmpty)
              _buildFilteredEmpty()
            else
              ...visible.map(
                (property) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _PropertyCard(
                    property: property,
                    formatDate: _formatDateOnly,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // Sections secondaires repliées par défaut pour aérer l'écran.
            if (_ticketCountsByBuilding.isNotEmpty)
              _CollapsibleSection(
                title: 'Tickets par bâtiment',
                subtitle: 'Tickets ouverts regroupés par immeuble.',
                children: _ticketCountsByBuilding
                    .map((count) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TicketCountCard(count: count),
                        ))
                    .toList(),
              ),
            if (_data.backlog.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _CollapsibleSection(
                title: 'File de travaux',
                subtitle: 'Unités qui nécessitent une intervention ou une relance.',
                children: _data.backlog
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _BacklogCard(
                            item: item,
                            formatDate: _formatDate,
                          ),
                        ))
                    .toList(),
              ),
            ],
            if (_data.tenantMessages.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _CollapsibleSection(
                title: 'Messages locataires',
                subtitle: 'État des derniers envois aux occupants concernés.',
                children: _data.tenantMessages
                    .map((message) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TenantMessageCard(
                            message: message,
                            formatDate: _formatDate,
                          ),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredEmpty() {
    final searching = _searchController.text.trim().isNotEmpty;
    return SizedBox(
      height: 320,
      child: EmptyState(
        icon: Icons.task_alt_outlined,
        iconColor: AppColors.success,
        title: searching
            ? 'Aucune propriété trouvée'
            : 'Aucune propriété ne nécessite d’action',
        description: searching
            ? 'Aucun immeuble ne correspond à votre recherche.'
            : 'Tout est à jour pour ce filtre. Changez de filtre pour voir '
                'l’ensemble des immeubles.',
        ctaLabel: 'Réinitialiser',
        ctaIcon: Icons.filter_alt_off_outlined,
        onCtaPressed: () {
          setState(() {
            _filter = _MaintenanceFilter.all;
            _searchController.clear();
          });
        },
      ),
    );
  }

  Widget _refreshable({required Widget child, bool fillViewport = false}) {
    return RefreshIndicator(
      onRefresh: _fetchCommandCenter,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: fillViewport
          ? LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: child,
                  ),
                );
              },
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: child,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// En-tête compact
// ---------------------------------------------------------------------------

class _HeaderSummary extends StatelessWidget {
  const _HeaderSummary({
    required this.asOf,
    required this.propertyCount,
    required this.degraded,
  });

  final DateTime? asOf;
  final int propertyCount;
  final bool degraded;

  @override
  Widget build(BuildContext context) {
    final updated = asOf == null
        ? '—'
        : DateFormat('d MMM HH:mm', 'fr').format(asOf!.toLocal());
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.construction_outlined,
              color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                degraded
                    ? 'Chargement dégradé'
                    : '$propertyCount propriété(s) suivie(s)',
                style: AppTypography.sectionHeader,
              ),
              const SizedBox(height: 2),
              Text(
                'Mise à jour : $updated',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
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
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Données partielles : $message',
              style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
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
        Text(title, style: AppTypography.sectionHeader),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1 + 2 — KPIs prioritaires cliquables
// ---------------------------------------------------------------------------

class _PriorityKpis extends StatelessWidget {
  const _PriorityKpis({
    required this.summary,
    required this.filter,
    required this.onTap,
  });

  final MaintenanceCommandCenterSummary summary;
  final _MaintenanceFilter filter;
  final ValueChanged<_MaintenanceFilter> onTap;

  @override
  Widget build(BuildContext context) {
    final ready = summary.dispatchableEmployeeCount;
    final cards = <Widget>[
      _PriorityKpiCard(
        title: 'Tâches en retard',
        value: summary.overdueTaskCount,
        icon: Icons.event_busy_outlined,
        accent: summary.overdueTaskCount > 0
            ? AppColors.error
            : AppColors.textMuted,
        selected: filter == _MaintenanceFilter.overdue,
        tooltip: 'Tâches dont l’échéance est dépassée. Touchez pour filtrer.',
        onTap: () => onTap(_MaintenanceFilter.overdue),
      ),
      _PriorityKpiCard(
        title: 'Bloqués',
        value: summary.blockedCount,
        icon: Icons.block_outlined,
        accent: summary.blockedCount > 0
            ? AppColors.warning
            : AppColors.textMuted,
        selected: filter == _MaintenanceFilter.blocked,
        tooltip: 'Logements bloqués par un obstacle. Touchez pour filtrer.',
        onTap: () => onTap(_MaintenanceFilter.blocked),
      ),
      _PriorityKpiCard(
        title: 'Demandes en cours',
        value: summary.pendingIntakeCount,
        icon: Icons.mark_email_unread_outlined,
        accent: summary.pendingIntakeCount > 0
            ? AppColors.info
            : AppColors.textMuted,
        selected: filter == _MaintenanceFilter.intake,
        tooltip: 'Demandes locataires en attente de traitement. '
            'Touchez pour filtrer.',
        onTap: () => onTap(_MaintenanceFilter.intake),
      ),
      _PriorityKpiCard(
        title: 'Tâches prêtes',
        value: ready,
        icon: Icons.groups_outlined,
        accent: ready > 0 ? AppColors.warning : AppColors.success,
        selected: filter == _MaintenanceFilter.ready,
        tooltip:
            'Employés disponibles à affecter à des tâches (dispatchables). '
            'Touchez pour filtrer.',
        onTap: () => onTap(_MaintenanceFilter.ready),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 2;
        const spacing = AppSpacing.md;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((card) => SizedBox(width: itemWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

class _PriorityKpiCard extends StatelessWidget {
  const _PriorityKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color accent;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.10)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(
                color: selected
                    ? accent
                    : accent.withValues(alpha: 0.18),
                width: selected ? 1.6 : 1,
              ),
              boxShadow: [AppSpacing.elevationCard],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                    const Spacer(),
                    Icon(
                      selected ? Icons.filter_alt : Icons.chevron_right,
                      color: accent,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$value',
                  style: AppTypography.kpiValue.copyWith(color: accent),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  title,
                  style: AppTypography.kpiLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Indicateurs secondaires (repliés)
// ---------------------------------------------------------------------------

class _SecondaryKpis extends StatelessWidget {
  const _SecondaryKpis({required this.summary});

  final MaintenanceCommandCenterSummary summary;

  @override
  Widget build(BuildContext context) {
    final messagesTooltip =
        '${summary.tenantMessageSentCount} envoyé(s) • '
        '${summary.tenantMessageFailedCount} en erreur • '
        '${summary.tenantMessagePendingCount} en attente';

    final tiles = <Widget>[
      _MiniStat(
        label: 'Propriétés',
        value: summary.propertyCount,
        icon: Icons.apartment_outlined,
      ),
      _MiniStat(
        label: 'Rénovations',
        value: summary.renovationCount,
        icon: Icons.construction_outlined,
      ),
      _MiniStat(
        label: 'Prêts',
        value: summary.readyCount,
        icon: Icons.verified_outlined,
        accent: AppColors.success,
      ),
      _MiniStat(
        label: 'Tâches à venir',
        value: summary.dueSoonTaskCount,
        icon: Icons.schedule_outlined,
        accent: AppColors.warning,
      ),
      _MiniStat(
        label: 'Commandes ouvertes',
        value: summary.openOrderCount,
        icon: Icons.inventory_2_outlined,
        accent: AppColors.info,
      ),
      _MiniStat(
        label: 'Messages',
        value: summary.tenantMessageSentCount,
        icon: Icons.sms_outlined,
        accent: summary.tenantMessageFailedCount > 0
            ? AppColors.error
            : AppColors.success,
        tooltip: messagesTooltip,
      ),
    ];

    return _CollapsibleSection(
      title: 'Tous les indicateurs',
      subtitle: 'Vue d’ensemble détaillée de la charge et des communications.',
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: tiles,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accent = AppColors.primary,
    this.tooltip,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // 1 — Atténue les indicateurs à zéro pour réduire le bruit visuel.
    final isZero = value == 0;
    final effectiveAccent = isZero ? AppColors.textMuted : accent;

    final tile = Opacity(
      opacity: isZero ? 0.5 : 1,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: effectiveAccent, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: AppTypography.bodyBold
                        .copyWith(color: AppColors.textPrimary),
                  ),
                  Text(
                    label,
                    style: AppTypography.chartAxisLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (tooltip != null)
              const Icon(Icons.info_outline,
                  size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: tile);
    }
    return tile;
  }
}

// ---------------------------------------------------------------------------
// 4 — Barre d'outils : recherche, tri, filtres rapides
// ---------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchController,
    required this.sortMode,
    required this.filter,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onFilterChanged,
  });

  final TextEditingController searchController;
  final _SortMode sortMode;
  final _MaintenanceFilter filter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_SortMode> onSortChanged;
  final ValueChanged<_MaintenanceFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: 'Rechercher une adresse…',
            hintStyle:
                AppTypography.body.copyWith(color: AppColors.textMuted),
            prefixIcon:
                const Icon(Icons.search, color: AppColors.textMuted, size: 20),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.textMuted, size: 18),
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.md),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _FilterChip(
                    label: 'À traiter',
                    selected: filter == _MaintenanceFilter.actionNeeded,
                    onSelected: () =>
                        onFilterChanged(_MaintenanceFilter.actionNeeded),
                  ),
                  _FilterChip(
                    label: 'Bloqué',
                    selected: filter == _MaintenanceFilter.blocked,
                    onSelected: () =>
                        onFilterChanged(_MaintenanceFilter.blocked),
                  ),
                  _FilterChip(
                    label: 'Tout',
                    selected: filter == _MaintenanceFilter.all,
                    onSelected: () => onFilterChanged(_MaintenanceFilter.all),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _SortDropdown(sortMode: sortMode, onChanged: onSortChanged),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: AppTypography.chipLabel.copyWith(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.sortMode, required this.onChanged});

  final _SortMode sortMode;
  final ValueChanged<_SortMode> onChanged;

  String _label(_SortMode mode) {
    switch (mode) {
      case _SortMode.overdue:
        return 'Tâches en retard';
      case _SortMode.dueDate:
        return 'Échéance';
      case _SortMode.name:
        return 'Nom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_SortMode>(
          value: sortMode,
          isDense: true,
          dropdownColor: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          icon: const Icon(Icons.sort, color: AppColors.textSecondary, size: 18),
          style: AppTypography.chipLabel.copyWith(color: AppColors.textPrimary),
          items: _SortMode.values
              .map(
                (mode) => DropdownMenuItem<_SortMode>(
                  value: mode,
                  child: Text('Trier : ${_label(mode)}'),
                ),
              )
              .toList(),
          onChanged: (mode) {
            if (mode != null) onChanged(mode);
          },
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.only(
            left: AppSpacing.md, right: AppSpacing.xs, top: 4, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filtre actif : $label',
              style: AppTypography.chipLabel.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.close, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3 — Carte de propriété repliable
// ---------------------------------------------------------------------------

class _PropertyCard extends StatefulWidget {
  const _PropertyCard({required this.property, required this.formatDate});

  final MaintenanceCommandCenterProperty property;
  final String Function(DateTime?) formatDate;

  @override
  State<_PropertyCard> createState() => _PropertyCardState();
}

class _PropertyCardState extends State<_PropertyCard> {
  bool _expanded = false;

  ({String label, Color color}) get _criticalBadge {
    final p = widget.property;
    if (p.overdueTaskCount > 0) {
      return (label: '${p.overdueTaskCount} en retard', color: AppColors.error);
    }
    if (p.blockedCount > 0) {
      return (label: '${p.blockedCount} bloqué(s)', color: AppColors.warning);
    }
    if (p.dueSoonTaskCount > 0) {
      return (label: '${p.dueSoonTaskCount} à venir', color: AppColors.warning);
    }
    if (p.pendingIntakeCount > 0) {
      return (
        label: '${p.pendingIntakeCount} demande(s)',
        color: AppColors.info
      );
    }
    if (p.readyCount > 0) {
      return (label: '${p.readyCount} prêt(s)', color: AppColors.success);
    }
    return (label: 'À jour', color: AppColors.success);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    final critical = _criticalBadge;

    final subtitleParts = <String>['${p.unitCount} unité(s)'];
    if (p.renovationCount > 0) {
      subtitleParts.add('${p.renovationCount} rénovation(s)');
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
        boxShadow: [AppSpacing.elevationCard],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
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
                            p.buildingName,
                            style: AppTypography.cardTitle.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleParts.join(' • '),
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(
                        label: critical.label, color: critical.color),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildExpanded(p),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpanded(MaintenanceCommandCenterProperty p) {
    // Badges : uniquement les valeurs non nulles.
    final badges = <Widget>[
      if (p.blockedCount > 0)
        _StatusChip(label: '${p.blockedCount} bloqué(s)', color: AppColors.warning),
      if (p.overdueTaskCount > 0)
        _StatusChip(
            label: '${p.overdueTaskCount} en retard', color: AppColors.error),
      if (p.dueSoonTaskCount > 0)
        _StatusChip(
            label: '${p.dueSoonTaskCount} à venir', color: AppColors.warning),
      if (p.readyCount > 0)
        _StatusChip(label: '${p.readyCount} prêt(s)', color: AppColors.success),
      if (p.openOrderCount > 0)
        _StatusChip(
            label: '${p.openOrderCount} commande(s)', color: AppColors.info),
      if (p.pendingIntakeCount > 0)
        _StatusChip(
            label: '${p.pendingIntakeCount} demande(s)',
            color: AppColors.indigo),
      if (p.tenantMessageStats.total > 0)
        Tooltip(
          message:
              '${p.tenantMessageStats.sent}/${p.tenantMessageStats.total} message(s) envoyé(s)',
          child: const _StatusChip(label: 'Messages', color: AppColors.primary),
        ),
    ];

    // Détails capacité (lignes non nulles uniquement).
    final capacityLines = <String>[
      if (p.capacity.candidateCount > 0)
        'Candidats : ${p.capacity.candidateCount}',
      if (p.capacity.dispatchableCount > 0)
        'Tâches prêtes : ${p.capacity.dispatchableCount}',
      if (p.capacity.totalOpenTasks > 0)
        'Tâches ouvertes : ${p.capacity.totalOpenTasks}',
      if (p.capacity.buildingOpenTasks > 0)
        'Tâches immeuble : ${p.capacity.buildingOpenTasks}',
    ];

    final milestoneLines = <String>[
      if (p.nextDueAt != null) 'Échéance : ${widget.formatDate(p.nextDueAt)}',
      if (p.tenantMessageStats.latestAt != null)
        'Dernier message : ${widget.formatDate(p.tenantMessageStats.latestAt)}',
    ];

    final infoBlocks = <Widget>[
      if (capacityLines.isNotEmpty)
        Expanded(child: _InfoBlock(title: 'Capacité', lines: capacityLines)),
      if (capacityLines.isNotEmpty && milestoneLines.isNotEmpty)
        const SizedBox(width: AppSpacing.sm),
      if (milestoneLines.isNotEmpty)
        Expanded(
            child: _InfoBlock(title: 'Prochain jalon', lines: milestoneLines)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badges.isNotEmpty)
          Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: badges),
        if (infoBlocks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: infoBlocks,
            ),
          ),
        ],
        if (p.backlog.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Sous-file',
            style: AppTypography.chipLabel
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: p.backlog
                .map((item) => _StatusChip(
                      label: '${item.unitLabel} · ${_phaseLabel(item.phase)}',
                      color: _phaseColor(item.phase),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Section repliable générique
// ---------------------------------------------------------------------------

class _CollapsibleSection extends StatelessWidget {
  const _CollapsibleSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(title, style: AppTypography.cardTitle),
          subtitle: Text(
            subtitle,
            style: AppTypography.chartAxisLabel,
          ),
          children: children,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cartes secondaires (file de travaux / messages / tickets)
// ---------------------------------------------------------------------------

class _BacklogCard extends StatelessWidget {
  const _BacklogCard({required this.item, required this.formatDate});

  final MaintenanceCommandCenterBacklogItem item;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (item.overdueTaskCount > 0)
        _StatusChip(
            label: '${item.overdueTaskCount} en retard', color: AppColors.error),
      if (item.dueSoonTaskCount > 0)
        _StatusChip(
            label: '${item.dueSoonTaskCount} à venir', color: AppColors.warning),
      if (item.assignedEmployeeLabel.isNotEmpty)
        _StatusChip(label: item.assignedEmployeeLabel, color: AppColors.info),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item.buildingName} · Logement ${item.unitLabel}',
                  style: AppTypography.cardTitle
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(
                  label: _phaseLabel(item.phase),
                  color: _phaseColor(item.phase)),
            ],
          ),
          if (item.nextStep.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(item.nextStep, style: AppTypography.caption),
          ],
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: badges),
          ],
          if (item.nextDueAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Échéance ${formatDate(item.nextDueAt)}',
              style: AppTypography.chartAxisLabel,
            ),
          ],
        ],
      ),
    );
  }
}

class _TenantMessageCard extends StatelessWidget {
  const _TenantMessageCard({required this.message, required this.formatDate});

  final MaintenanceCommandCenterTenantMessage message;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(message.status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.sms_outlined, color: color, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${message.buildingName ?? '—'} · ${message.unitLabel ?? 'Logement'}',
                        style: AppTypography.cardTitle
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _StatusChip(label: _statusLabel(message.status), color: color),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message.errorMessage?.isNotEmpty == true
                      ? message.errorMessage!
                      : 'Dernier envoi : ${formatDate(message.lastSentAt)}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCountCard extends StatelessWidget {
  const _TicketCountCard({required this.count});

  final BuildingTicketCount count;

  @override
  Widget build(BuildContext context) {
    final hasTickets = count.total > 0;
    final accent = hasTickets ? AppColors.error : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasTickets
                      ? Icons.build_outlined
                      : Icons.check_circle_outline,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  count.buildingName,
                  style: AppTypography.cardTitle
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${count.total}',
                  style: AppTypography.bodyBold.copyWith(color: accent),
                ),
              ),
            ],
          ),
          if (hasTickets) ...[
            const SizedBox(height: AppSpacing.md),
            _UrgencyBar(count: count),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (count.urgence > 0)
                  _StatusChip(label: 'Urgence ${count.urgence}', color: AppColors.error),
                if (count.haute > 0)
                  _StatusChip(label: 'Haute ${count.haute}', color: AppColors.warning),
                if (count.moyenne > 0)
                  _StatusChip(label: 'Moyenne ${count.moyenne}', color: AppColors.info),
                if (count.basse > 0)
                  _StatusChip(label: 'Basse ${count.basse}', color: AppColors.success),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/maintenance-tickets'),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Voir'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'urgence empilée (urgence / haute / moyenne / basse) proportionnelle.
class _UrgencyBar extends StatelessWidget {
  const _UrgencyBar({required this.count});

  final BuildingTicketCount count;

  @override
  Widget build(BuildContext context) {
    final segments = <Widget>[
      if (count.urgence > 0)
        Expanded(flex: count.urgence, child: const ColoredBox(color: AppColors.error)),
      if (count.haute > 0)
        Expanded(flex: count.haute, child: const ColoredBox(color: AppColors.warning)),
      if (count.moyenne > 0)
        Expanded(flex: count.moyenne, child: const ColoredBox(color: AppColors.info)),
      if (count.basse > 0)
        Expanded(flex: count.basse, child: const ColoredBox(color: AppColors.success)),
    ];
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(height: 8, child: Row(children: segments)),
    );
  }
}

// ---------------------------------------------------------------------------
// Petits composants partagés
// ---------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
            style: AppTypography.chipLabel.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                line,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers de libellés / couleurs partagés
// ---------------------------------------------------------------------------

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
