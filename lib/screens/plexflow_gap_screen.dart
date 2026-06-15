import 'package:flutter/material.dart';

import '../services/plexflow_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class PlexFlowGapScreen extends StatefulWidget {
  const PlexFlowGapScreen({super.key});

  @override
  State<PlexFlowGapScreen> createState() => _PlexFlowGapScreenState();
}

class _PlexFlowGapScreenState extends State<PlexFlowGapScreen> {
  bool _isLoading = true;
  Object? _lastError;
  List<Map<String, dynamic>> _buildings = [];
  Map<String, Map<String, dynamic>> _gapCache = {};
  String? _selectedBuildingId;
  bool _isIngesting = false;

  @override
  void initState() {
    super.initState();
    _fetchBuildings();
  }

  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    try {
      final buildings = await PlexFlowService.instance.getBuildings();
      if (!mounted) return;
      setState(() {
        _buildings = buildings;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGap(String buildingId) async {
    setState(() => _selectedBuildingId = buildingId);
    try {
      final gap = await PlexFlowService.instance.getGapAnalysis(buildingId);
      if (!mounted) return;
      setState(() => _gapCache[buildingId] = gap);
    } catch (e) {
      if (!mounted) return;
      setState(() => _gapCache[buildingId] = {'error': e.toString()});
    }
  }

  Future<void> _ingest(String buildingId) async {
    setState(() => _isIngesting = true);
    try {
      final result = await PlexFlowService.instance.ingestMissing(buildingId);
      if (!mounted) return;
      setState(() => _isIngesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Importation: ${result['createdUnits'] ?? 0} unités, '
            '${result['createdLeases'] ?? 0} baux, '
            '${result['updatedTenants'] ?? 0} locataires',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      // Rafraîchir le gap après ingestion
      _fetchGap(buildingId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isIngesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'PlexFlow — Analyse des écarts'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: false);
    if (_lastError != null) {
      return ErrorState(error: _lastError!, onRetry: _fetchBuildings);
    }
    if (_buildings.isEmpty) {
      return const EmptyState(
        title: 'Aucun bâtiment PlexFlow',
        description: 'Configurez PLEXFLOW_API_URL pour voir les données.',
        icon: Icons.cloud_off_outlined,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'Bâtiments PlexFlow',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sélectionnez un bâtiment pour voir les écarts avec ImmoGestion.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        ..._buildings.map((b) {
          final id = b['id'] as String? ?? '';
          final name = b['name'] as String? ?? b['label'] as String? ?? 'Sans nom';
          final isSelected = _selectedBuildingId == id;
          final gap = _gapCache[id];

          return Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: ExpansionTile(
              initiallyExpanded: isSelected,
              onExpansionChanged: (expanded) {
                if (expanded && gap == null) _fetchGap(id);
              },
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: gap != null
                  ? (() {
                      final summary = gap['summary'] as Map<String, dynamic>?;
                      final missing = (summary?['missingCount'] as num?)?.toInt() ?? 0;
                      return Text(
                        '$missing éléments manquants',
                        style: TextStyle(
                          fontSize: 12,
                          color: missing > 0 ? AppColors.warning : AppColors.success,
                        ),
                      );
                    })()
                  : const Text('Appuyez pour analyser', style: TextStyle(fontSize: 12)),
              children: [
                if (gap == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (gap['error'] != null)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Erreur: ${gap['error']}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else ...[
                  _GapSection(
                    title: 'Unités manquantes',
                    count: (gap['missingUnits'] as List<dynamic>?)?.length ?? 0,
                    icon: Icons.apartment_outlined,
                    color: AppColors.warning,
                    items: (gap['missingUnits'] as List<dynamic>? ?? [])
                        .map((u) => _gapItemLabel(u))
                        .toList(),
                  ),
                  _GapSection(
                    title: 'Baux manquants',
                    count: (gap['missingLeases'] as List<dynamic>?)?.length ?? 0,
                    icon: Icons.description_outlined,
                    color: AppColors.info,
                    items: (gap['missingLeases'] as List<dynamic>? ?? [])
                        .map((l) => _gapItemLabel(l))
                        .toList(),
                  ),
                  _GapSection(
                    title: 'Locataires manquants',
                    count: (gap['missingTenants'] as List<dynamic>?)?.length ?? 0,
                    icon: Icons.people_outlined,
                    color: AppColors.primary,
                    items: (gap['missingTenants'] as List<dynamic>? ?? [])
                        .map((t) => _gapItemLabel(t))
                        .toList(),
                  ),
                  if ((() {
                        final summary = gap['summary'] as Map<String, dynamic>?;
                        final missing = (summary?['missingCount'] as num?)?.toInt() ?? 0;
                        return missing > 0;
                      })())
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: _isIngesting ? null : () => _ingest(id),
                          icon: _isIngesting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download_rounded),
                          label: Text(_isIngesting ? 'Importation...' : 'Importer les données manquantes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _gapItemLabel(dynamic item) {
    final m = item as Map<String, dynamic>? ?? {};
    return m['label'] as String? ?? m['name'] as String? ?? m['unitLabel'] as String? ?? '—';
  }
}

class _GapSection extends StatelessWidget {
  const _GapSection({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
              const SizedBox(width: 8),
              StatusBadge(
                label: '$count',
                variant: count > 0 ? BadgeVariant.warning : BadgeVariant.success,
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2, left: 26),
                  child: Text(
                    '• $item',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
