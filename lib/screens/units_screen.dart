import 'package:flutter/material.dart';

import '../models.dart';
import '../services/unit_service.dart';
import 'unit_detail_screen.dart';

class UnitsScreen extends StatefulWidget {
  const UnitsScreen({super.key, this.buildingId, this.buildingName});

  final String? buildingId;
  final String? buildingName;

  @override
  State<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends State<UnitsScreen> {
  List<BuildingItem> _buildings = [];
  String? _selectedBuildingId;
  List<UnitItem> _units = [];
  List<UnitItem> _filteredUnits = [];
  bool _isLoadingBuildings = true;
  bool _isLoadingUnits = false;
  String? _errorMessage;
  VacancyStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    if (widget.buildingId != null) {
      _selectedBuildingId = widget.buildingId;
      _fetchUnits();
    }
    _fetchBuildings();
  }

  Future<void> _fetchBuildings() async {
    setState(() {
      _isLoadingBuildings = true;
      _errorMessage = null;
    });
    try {
      final buildings = await UnitService.instance.getBuildings();
      setState(() {
        _buildings = buildings;
        _isLoadingBuildings = false;
        if (_selectedBuildingId == null && buildings.isNotEmpty) {
          _selectedBuildingId = buildings.first.id;
          _fetchUnits();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingBuildings = false;
      });
    }
  }

  Future<void> _fetchUnits() async {
    if (_selectedBuildingId == null) return;
    setState(() {
      _isLoadingUnits = true;
      _errorMessage = null;
    });
    try {
      final units =
          await UnitService.instance.getUnitsByBuilding(_selectedBuildingId!);
      setState(() {
        _units = units;
        _applyFilter();
        _isLoadingUnits = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingUnits = false;
      });
    }
  }

  void _applyFilter() {
    setState(() {
      if (_filterStatus == null) {
        _filteredUnits = List.of(_units);
      } else {
        _filteredUnits =
            _units.where((u) => u.vacancyStatus == _filterStatus).toList();
      }
    });
  }

  String? _selectedBuildingName() {
    if (widget.buildingName != null) return widget.buildingName;
    final building = _buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => const BuildingItem(
        name: '',
        address: '',
        city: '',
        totalUnits: 0,
        occupiedUnits: 0,
        monthlyRevenue: 0,
        units: [],
      ),
    );
    return building.name.isNotEmpty ? building.name : null;
  }

  int _vacantCount() =>
      _units.where((u) => u.vacancyStatus == VacancyStatus.vacant).length;

  int _occupiedCount() =>
      _units.where((u) => u.vacancyStatus == VacancyStatus.occupied).length;

  int _maintenanceCount() =>
      _units.where((u) => u.vacancyStatus == VacancyStatus.maintenance).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedBuildingName() ?? 'Unités'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingBuildings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger les données',
                style: const TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _fetchBuildings();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    if (_buildings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apartment_outlined,
                  size: 64, color: Color(0xFF94A3B8)),
              const SizedBox(height: 16),
              const Text(
                'Aucun immeuble enregistré',
                style: TextStyle(fontSize: 16, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ajoutez un immeuble pour gérer ses unités',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchUnits,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.buildingId == null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBuildingId,
                    isExpanded: true,
                    hint: const Text(
                      'Sélectionner un immeuble',
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    items: _buildings.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.id,
                        child: Row(
                          children: [
                            const Icon(Icons.apartment,
                                size: 18, color: Color(0xFF0F766E)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                b.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBuildingId = value;
                          _filterStatus = null;
                        });
                        _fetchUnits();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Vacancy summary chips
            Row(
              children: [
                _buildCountChip(
                  label: 'Total',
                  count: _units.length,
                  color: const Color(0xFF1E293B),
                  isSelected: _filterStatus == null,
                  onTap: () {
                    setState(() => _filterStatus = null);
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 8),
                _buildCountChip(
                  label: 'Libres',
                  count: _vacantCount(),
                  color: VacancyStatus.vacant.color,
                  isSelected: _filterStatus == VacancyStatus.vacant,
                  onTap: () {
                    setState(() =>
                        _filterStatus = _filterStatus == VacancyStatus.vacant
                            ? null
                            : VacancyStatus.vacant);
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 8),
                _buildCountChip(
                  label: 'Occupées',
                  count: _occupiedCount(),
                  color: VacancyStatus.occupied.color,
                  isSelected: _filterStatus == VacancyStatus.occupied,
                  onTap: () {
                    setState(() => _filterStatus =
                        _filterStatus == VacancyStatus.occupied
                            ? null
                            : VacancyStatus.occupied);
                    _applyFilter();
                  },
                ),
                const SizedBox(width: 8),
                _buildCountChip(
                  label: 'Maintenance',
                  count: _maintenanceCount(),
                  color: VacancyStatus.maintenance.color,
                  isSelected: _filterStatus == VacancyStatus.maintenance,
                  onTap: () {
                    setState(() => _filterStatus =
                        _filterStatus == VacancyStatus.maintenance
                            ? null
                            : VacancyStatus.maintenance);
                    _applyFilter();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_isLoadingUnits)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_filteredUnits.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.door_front_door_outlined,
                          size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        _units.isEmpty
                            ? 'Aucune unité dans cet immeuble'
                            : 'Aucune unité ne correspond au filtre',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_filterStatus != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            setState(() => _filterStatus = null);
                            _applyFilter();
                          },
                          child: const Text('Effacer le filtre'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredUnits.length,
                itemBuilder: (context, index) {
                  final unit = _filteredUnits[index];
                  return _buildUnitCard(unit);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                  color: isSelected ? color : const Color(0xFF1E293B),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? color : const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitCard(UnitItem unit) {
    final vacancy = unit.vacancyStatus;
    final tenantLabel = unit.tenantName ?? unit.tenant;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UnitDetailScreen(unit: unit),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: vacancy.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.door_front_door,
                        color: vacancy.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            unit.number,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (unit.type.isNotEmpty)
                            Text(
                              unit.type,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: vacancy.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        vacancy.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: vacancy.color,
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
                        size: 16, color: Color(0xFF10B981)),
                    const SizedBox(width: 4),
                    Text(
                      '${unit.rent}\$ / mois',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const Spacer(),
                    if (unit.bedrooms > 0) ...[
                      const Icon(Icons.bed_outlined,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 2),
                      Text(
                        '${unit.bedrooms} ch.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                    if (unit.bathrooms > 0) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.bathtub_outlined,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 2),
                      Text(
                        '${unit.bathrooms} SdB',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
                if (tenantLabel != null && tenantLabel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          tenantLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
