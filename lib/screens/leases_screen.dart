import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'lease_detail_screen.dart';
import 'lease_form_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';

class LeasesScreen extends StatefulWidget {
  const LeasesScreen({super.key});

  @override
  State<LeasesScreen> createState() => _LeasesScreenState();
}

class _LeasesScreenState extends State<LeasesScreen> {
  List<LeaseItem> _allLeases = [];
  List<LeaseItem> _filteredLeases = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  LeaseStatus? _filterStatus;
  String? _filterBuildingId;
  List<BuildingItem> _buildings = [];

  @override
  void initState() {
    super.initState();
    _fetchLeases();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredLeases = _allLeases.where((lease) {
        if (_filterStatus != null && lease.leaseStatus != _filterStatus) return false;
        if (_filterBuildingId != null && lease.buildingId != _filterBuildingId) return false;
        if (query.isNotEmpty) {
          final tenantName = (lease.tenantName ?? '').toLowerCase();
          if (!tenantName.contains(query)) return false;
        }
        return true;
      }).toList();
    });
  }

  Future<void> _fetchLeases() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.get('/leases'),
        ApiService.instance.get('/buildings'),
      ]);

      final leasesData = results[0]['data'] as List<dynamic>;
      final leases = leasesData
          .map((e) => LeaseItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final buildingsData = results[1]['data'] as List<dynamic>;
      final buildings = buildingsData
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      leases.sort((a, b) {
        final bCreated = b.createdAt ?? DateTime(2000);
        final aCreated = a.createdAt ?? DateTime(2000);
        return bCreated.compareTo(aCreated);
      });

      setState(() {
        _allLeases = leases;
        _filteredLeases = leases;
        _buildings = buildings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Baux', actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (_) => const LeaseFormScreen(),
                  fullscreenDialog: true,
                ),
              )
                  .then((_) {
                if (mounted) _fetchLeases();
              });
            },
          ),
        ]),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
                'Impossible de charger les baux',
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
              onPressed: _fetchLeases,
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

    return RefreshIndicator(
      onRefresh: _fetchLeases,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: AppSpacing.cardDecoration(),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher par locataire...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Filter chips row
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip('Tous', null),
                  ...LeaseStatus.values.map((s) => _buildFilterChip(s.label, s)),
                ],
              ),
            ),

            // Building filter dropdown
            if (_buildings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: _filterBuildingId,
                    isExpanded: true,
                    hint: const Text(
                      'Tous les immeubles',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tous les immeubles'),
                      ),
                      ..._buildings.map((b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(b.name, overflow: TextOverflow.ellipsis),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() => _filterBuildingId = v);
                      _applyFilters();
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Status summary
            _buildStatusSummary(),

            const SizedBox(height: 24),

            // Leases grouped by building
            if (_filteredLeases.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun bail trouvé',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              _buildGroupedList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, LeaseStatus? status) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _filterStatus = isSelected ? null : status);
          _applyFilters();
        },
        selectedColor: (status?.color ?? AppColors.primary).withOpacity( 0.15),
        labelStyle: TextStyle(
          color: isSelected
              ? (status?.color ?? AppColors.primary)
              : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
        side: BorderSide(
          color: isSelected
              ? (status?.color ?? AppColors.primary)
              : AppColors.border,
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildStatusSummary() {
    final counts = <LeaseStatus, int>{};
    for (final lease in _allLeases) {
      counts[lease.leaseStatus] = (counts[lease.leaseStatus] ?? 0) + 1;
    }

    return Row(
      children: LeaseStatus.values.map((s) {
        final count = counts[s] ?? 0;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity( 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: s.color,
                  ),
                ),
                Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 10,
                    color: s.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupedList() {
    final grouped = <String, List<LeaseItem>>{};
    for (final lease in _filteredLeases) {
      final key = lease.buildingName ?? 'Sans immeuble';
      grouped.putIfAbsent(key, () => []).add(lease);
    }

    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final buildingName in sortedKeys) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              buildingName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...grouped[buildingName]!.map((lease) => _buildLeaseCard(lease)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildLeaseCard(LeaseItem lease) {
    final statusColor = lease.leaseStatus.color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LeaseDetailScreen(
                  lease: lease,
                  onLeaseChanged: _fetchLeases,
                ),
              ),
            ).then((_) {
              if (mounted) _fetchLeases();
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        lease.leaseStatus.icon,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lease.tenantName ?? 'Sans locataire',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lease.unitLabel ?? 'Sans unité',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity( 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        lease.leaseStatus.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.attach_money,
                        size: 16, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      lease.displayRent,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${lease.displayStartDate} — ${lease.displayEndDate}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
