import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';
import 'building_form_screen.dart';
import 'units_screen.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<BuildingItem> _buildings = [];
  List<BuildingItem> _filteredBuildings = [];
  bool _isLoading = true;
  Object? _lastError;
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBuildings();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBuildings = _buildings
          .where((b) =>
              b.name.toLowerCase().contains(query) ||
              b.address.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    try {
      final response = await ApiService.instance.get('/buildings');
      final data = response['data'] as List<dynamic>;
      final buildings = data
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() {
        _buildings = buildings;
        _filteredBuildings = buildings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastError = e;
        _isLoading = false;
      });
    }
  }

  int get _totalUnits => _buildings.fold(0, (s, b) => s + b.totalUnits);
  int get _occupiedUnits => _buildings.fold(0, (s, b) => s + b.occupiedUnits);
  double get _portfolioOccupancy =>
      _totalUnits > 0 ? _occupiedUnits / _totalUnits : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Immeubles', actions: [
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          tooltip: _isGridView ? 'Vue liste' : 'Vue grille',
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          onPressed: _fetchBuildings,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Ajouter un immeuble',
          onPressed: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const BuildingFormScreen()),
            );
            if (result == true && mounted) _fetchBuildings();
          },
        ),
      ]),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: true);
    if (_lastError != null) {
      return ErrorState(error: _lastError!, onRetry: _fetchBuildings);
    }
    if (_buildings.isEmpty) {
      return const EmptyState(
        title: 'Aucun immeuble',
        description:
            'Ajoutez votre premier immeuble pour commencer à gérer votre parc immobilier.',
        icon: Icons.apartment_outlined,
        ctaLabel: 'Ajouter un immeuble',
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        _buildPortfolioSummary(),
        Expanded(
          child: _isGridView ? _buildGridView() : _buildListView(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un immeuble...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildPortfolioSummary() {
    final occPct = (_portfolioOccupancy * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _summaryChip(Icons.apartment, '${_buildings.length} immeubles'),
            const SizedBox(width: 16),
            _summaryChip(Icons.meeting_room, '$_totalUnits unités'),
            const SizedBox(width: 16),
            _summaryChip(Icons.pie_chart, '$occPct% occupé'),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label, style: AppTypography.caption),
      ],
    );
  }

  Widget _buildGridView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = Responsive.gridColumns(constraints.maxWidth);
        return GridView.builder(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.pagePadding(constraints.maxWidth),
            vertical: 12,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: columns == 1 ? 2.5 : 1.4,
          ),
          itemCount: _filteredBuildings.length,
          itemBuilder: (context, index) =>
              _buildBuildingCard(_filteredBuildings[index]),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _filteredBuildings.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildBuildingListTile(_filteredBuildings[index]),
      ),
    );
  }

  Widget _buildBuildingCard(BuildingItem building) {
    final occRate = building.totalUnits > 0
        ? building.occupiedUnits / building.totalUnits
        : 0.0;
    final occPct = (occRate * 100).round();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openUnits(building),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo de façade
            _buildStreetViewImage(building),
            // Infos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      building.name,
                      style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      building.address,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    // Badge occupation
                    Row(
                      children: [
                        StatusBadge(
                          label: '${building.occupiedUnits}/${building.totalUnits}',
                          variant: occRate >= 0.85
                              ? BadgeVariant.success
                              : occRate >= 0.60
                                  ? BadgeVariant.warning
                                  : BadgeVariant.danger,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$occPct%',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Barre de progression
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: occRate,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          occRate >= 0.85
                              ? AppColors.success
                              : occRate >= 0.60
                                  ? AppColors.warning
                                  : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Boutons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _openUnits(building),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              side: BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Unités', style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingListTile(BuildingItem building) {
    final occRate = building.totalUnits > 0
        ? building.occupiedUnits / building.totalUnits
        : 0.0;
    final occPct = (occRate * 100).round();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openUnits(building),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Mini photo
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: _buildStreetViewImage(building, mini: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(building.name,
                        style: AppTypography.sectionHeader.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(building.address,
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StatusBadge(
                          label: '${building.occupiedUnits}/${building.totalUnits}',
                          variant: occRate >= 0.85
                              ? BadgeVariant.success
                              : occRate >= 0.60
                                  ? BadgeVariant.warning
                                  : BadgeVariant.danger,
                        ),
                        const SizedBox(width: 6),
                        Text('$occPct%',
                            style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreetViewImage(BuildingItem building, {bool mini = false}) {
    final hasCoords = building.properties != null &&
        building.properties!['latitude'] != null &&
        building.properties!['longitude'] != null;

    if (!hasCoords) {
      return Container(
        color: AppColors.surface,
        child: Center(
          child: Icon(
            Icons.apartment,
            size: mini ? 32 : 48,
            color: AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final imageUrl = '/api/buildings/${building.id}/streetview';

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: AppColors.surface,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: AppColors.surface,
        child: Center(
          child: Icon(
            Icons.apartment,
            size: mini ? 32 : 48,
            color: AppColors.textMuted.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  void _openUnits(BuildingItem building) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnitsScreen(
          buildingId: building.id,
          buildingName: building.name,
        ),
      ),
    );
  }
}
