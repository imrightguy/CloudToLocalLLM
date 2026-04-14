import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'units_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';

class BuildingsScreen extends StatefulWidget {
  const BuildingsScreen({super.key});

  @override
  State<BuildingsScreen> createState() => _BuildingsScreenState();
}

class _BuildingsScreenState extends State<BuildingsScreen> {
  List<BuildingItem> _buildings = [];
  List<BuildingItem> _filteredBuildings = [];
  bool _isLoading = true;
  String? _errorMessage;
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
      _errorMessage = null;
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
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Immeubles', actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Ajouter un immeuble'),
                  content: const Text(
                    'La création d\'immeubles sera disponible dans une prochaine version.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
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
                'Impossible de charger les immeubles',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchBuildings,
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
      onRefresh: _fetchBuildings,
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
                        hintText: 'Rechercher un immeuble...',
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

            const SizedBox(height: 24),

            // Buildings list
            if (_filteredBuildings.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun immeuble trouvé',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredBuildings.length,
                itemBuilder: (context, index) {
                  final building = _filteredBuildings[index];
                  return _buildBuildingCard(building);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingCard(BuildingItem building) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Building header image placeholder
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.indigoTint,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Center(
                child: Icon(
                  Icons.apartment,
                  size: 48,
                  color: AppColors.indigo,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              building.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              building.address,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity( 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${building.occupiedUnits}/${building.totalUnits}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Occupancy progress
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Taux d'occupation",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(building.occupancyRate * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: building.occupancyRate,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Revenue info
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        '${building.monthlyRevenue}\$ / mois',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.home_work,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${building.totalUnits} unités',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _navigateToBuildingDetail(building),
                          child: const Text(
                            'Voir détails',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _navigateToUnits(building),
                          child: const Text(
                            'Voir unités',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.surface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToBuildingDetail(BuildingItem building) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _BuildingDetailScreen(building: building),
      ),
    );
  }

  void _navigateToUnits(BuildingItem building) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UnitsScreen(
          buildingId: building.id,
          buildingName: building.name,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Building detail screen showing units list
// ---------------------------------------------------------------------------

class _BuildingDetailScreen extends StatefulWidget {
  final BuildingItem building;
  const _BuildingDetailScreen({required this.building});

  @override
  State<_BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<_BuildingDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: widget.building.name,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Building info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.building.address,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                    if (widget.building.description != null &&
                        widget.building.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.building.description!,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          '${widget.building.occupiedUnits}/${widget.building.totalUnits} occupées',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${widget.building.monthlyRevenue}\$ / mois',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Unités',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.building.units.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucune unité',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.building.units.length,
                itemBuilder: (context, index) {
                  final unit = widget.building.units[index];
                  return _buildUnitCard(unit);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(UnitItem unit) {
    final isOccupied = unit.status.toLowerCase() == 'occupied' ||
        unit.status.toLowerCase() == 'occupé';
    final tenantLabel = unit.tenantName ?? unit.tenant;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${unit.number} - ${unit.type}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (tenantLabel != null && tenantLabel.isNotEmpty)
                      Text(
                        tenantLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? AppColors.success.withOpacity( 0.1)
                      : AppColors.warning.withOpacity( 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOccupied ? 'Occupé' : 'Libre',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOccupied
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (unit.id != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: () => _showEditUnitDialog(context, unit),
                  tooltip: 'Modifier l\'unité',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${unit.rent}\$ / mois',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${unit.bedrooms} ch.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (unit.leaseEnd.isNotEmpty) ...[
                const SizedBox(width: 16),
                Text(
                  'Fin: ${unit.leaseEnd}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showEditUnitDialog(BuildContext context, UnitItem unit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _EditUnitScreen(
          unit: unit,
          buildingId: widget.building.id ?? '',
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

// =============================================================================
// Edit Unit — full-screen form with tenant occupant fields
// =============================================================================

class _EditUnitScreen extends StatefulWidget {
  final UnitItem unit;
  final String buildingId;
  const _EditUnitScreen({required this.unit, required this.buildingId});

  @override
  State<_EditUnitScreen> createState() => _EditUnitScreenState();
}

class _EditUnitScreenState extends State<_EditUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _numberController;
  late final TextEditingController _typeController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _rentController;
  late final TextEditingController _tenantNameController;
  late final TextEditingController _tenantPhoneController;

  late String _status;
  DateTime? _tenantLeaseEnd;
  bool _tenantSectionExpanded = false;
  bool _isSubmitting = false;

  bool get _isOccupied =>
      _status.toLowerCase() == 'occupied' || _status.toLowerCase() == 'occupé';

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController(text: widget.unit.number);
    _typeController = TextEditingController(text: widget.unit.type);
    _bedroomsController =
        TextEditingController(text: widget.unit.bedrooms.toString());
    _rentController = TextEditingController(text: widget.unit.rent.toString());
    _tenantNameController =
        TextEditingController(text: widget.unit.tenantName ?? '');
    _tenantPhoneController =
        TextEditingController(text: widget.unit.tenantPhone ?? '');
    _status = widget.unit.status;
    _tenantLeaseEnd = widget.unit.tenantLeaseEnd;
    _tenantSectionExpanded = _isOccupied;
  }

  @override
  void dispose() {
    _numberController.dispose();
    _typeController.dispose();
    _bedroomsController.dispose();
    _rentController.dispose();
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.unit.id == null) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService.instance.put('/units/${widget.unit.id}', {
        'label': _numberController.text.trim(),
        'type': _typeController.text.trim(),
        'bedrooms': int.parse(_bedroomsController.text.trim()),
        'rentCents': int.parse(_rentController.text.trim()),
        'status': _status,
        if (_tenantNameController.text.trim().isNotEmpty)
          'tenantName': _tenantNameController.text.trim(),
        if (_tenantPhoneController.text.trim().isNotEmpty)
          'tenantPhone': _tenantPhoneController.text.trim(),
        if (_tenantLeaseEnd != null)
          'tenantLeaseEnd': _tenantLeaseEnd!.toIso8601String().split('T').first,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unité mise à jour avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Modifier ${widget.unit.number}', leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _numberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.door_front_door_outlined),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _bedroomsController,
                      decoration: const InputDecoration(
                        labelText: 'Chambres',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.bed_outlined),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _rentController,
                      decoration: const InputDecoration(
                        labelText: 'Loyer (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status dropdown
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: const [
                  DropdownMenuItem(value: 'occupied', child: Text('Occupé')),
                  DropdownMenuItem(value: 'available', child: Text('Libre')),
                  DropdownMenuItem(
                      value: 'maintenance', child: Text('En maintenance')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _status = v;
                      // Auto-expand tenant section when occupied
                      if (_isOccupied && !_tenantSectionExpanded) {
                        _tenantSectionExpanded = true;
                      }
                    });
                  }
                },
              ),

              // Collapsible tenant section — only when occupied
              if (_isOccupied) ...[
                const SizedBox(height: 24),
                Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    initiallyExpanded: _tenantSectionExpanded,
                    onExpansionChanged: (expanded) {
                      setState(() => _tenantSectionExpanded = expanded);
                    },
                    leading: const Icon(Icons.person_outline,
                        color: AppColors.primary),
                    title: const Text(
                      'Locataire actuel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 40, right: 0, top: 0, bottom: 8),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _tenantNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du locataire',
                                hintText: 'Ex: Jean Dupont',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _tenantPhoneController,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone du locataire',
                                hintText: 'Ex: (514) 555-1234',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _tenantLeaseEnd ??
                                      DateTime.now()
                                          .add(const Duration(days: 365)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now()
                                      .add(const Duration(days: 3650)),
                                );
                                if (picked != null) {
                                  setState(() => _tenantLeaseEnd = picked);
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Fin de bail',
                                  border: OutlineInputBorder(),
                                  prefixIcon:
                                      Icon(Icons.calendar_today_outlined),
                                  suffixIcon: Icon(Icons.arrow_drop_down),
                                ),
                                child: Text(
                                  _tenantLeaseEnd != null
                                      ? DateFormat('d MMMM yyyy', 'fr_CA')
                                          .format(_tenantLeaseEnd!)
                                      : 'Sélectionner une date',
                                  style: TextStyle(
                                    color: _tenantLeaseEnd != null
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Create Building — full-screen form
// =============================================================================

class _CreateBuildingScreen extends StatefulWidget {
  const _CreateBuildingScreen();

  @override
  State<_CreateBuildingScreen> createState() => _CreateBuildingScreenState();
}

class _CreateBuildingScreenState extends State<_CreateBuildingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController(text: 'Montréal');
  final _provinceController = TextEditingController(text: 'QC');
  final _postalCodeController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _totalUnitsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService.instance.post('/buildings', {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty
            ? 'Montréal'
            : _cityController.text.trim(),
        'province': _provinceController.text.trim().isEmpty
            ? 'QC'
            : _provinceController.text.trim(),
        'postalCode': _postalCodeController.text.trim().isEmpty
            ? null
            : _postalCodeController.text.trim(),
        'totalUnits': int.parse(_totalUnitsController.text.trim()),
        'properties': {
          if (_descriptionController.text.trim().isNotEmpty)
            'description': _descriptionController.text.trim(),
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Immeuble créé avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Nouvel immeuble', leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'immeuble *',
                  hintText: 'Ex: 1234 Rue Sainte-Catherine',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Nom requis (min 2 car.)'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse *',
                  hintText: 'Ex: 1234 Rue Sainte-Catherine',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Adresse requise (min 5 car.)'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ville',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      controller: _provinceController,
                      decoration: const InputDecoration(
                        labelText: 'Prov.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Code postal',
                        border: OutlineInputBorder(),
                        hintText: 'H2X 1Y4',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _totalUnitsController,
                decoration: const InputDecoration(
                  labelText: 'Nombre d\'unités *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.door_front_door),
                  hintText: 'Ex: 12',
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requis';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 1) return 'Doit être ≥ 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Créer l\'immeuble',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
