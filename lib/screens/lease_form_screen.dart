import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class LeaseFormScreen extends StatefulWidget {
  const LeaseFormScreen({super.key, this.lease});

  final LeaseItem? lease;

  @override
  State<LeaseFormScreen> createState() => _LeaseFormScreenState();
}

class _LeaseFormScreenState extends State<LeaseFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fetched options
  List<BuildingItem> _buildings = [];
  List<UnitItem> _units = [];
  bool _isLoadingOptions = true;
  String? _error;

  // Form fields
  String? _selectedBuildingId;
  String? _selectedUnitId;
  final _tenantNameController = TextEditingController();
  final _tenantEmailController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _rentController = TextEditingController();
  final _depositController = TextEditingController();
  final _notesController = TextEditingController();
  final _termsController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSubmitting = false;
  bool get _isEditing => widget.lease != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final lease = widget.lease!;
      _selectedBuildingId = lease.buildingId;
      _selectedUnitId = lease.unitId;
      _tenantNameController.text = lease.tenantName ?? '';
      _tenantEmailController.text = lease.tenantEmail ?? '';
      _tenantPhoneController.text = lease.tenantPhone ?? '';
      _rentController.text = lease.monthlyRent != null ? '${lease.monthlyRent}' : '';
      _depositController.text = lease.deposit != null ? '${lease.deposit}' : '';
      _notesController.text = lease.notes ?? '';
      _termsController.text = lease.terms ?? '';
      _startDate = lease.startDate;
      _endDate = lease.endDate;
    }
    _fetchOptions();
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantEmailController.dispose();
    _tenantPhoneController.dispose();
    _rentController.dispose();
    _depositController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final result = await ApiService.instance.get('/buildings');
      final data = result['data'] as List<dynamic>;
      final buildings = data
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      if (_isEditing && _selectedBuildingId != null) {
        final unitResult = await ApiService.instance
            .get('/buildings/$_selectedBuildingId/units');
        final unitData = unitResult['data'];
        if (unitData is List) {
          _units = unitData
              .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }

      setState(() {
        _buildings = buildings;
        _isLoadingOptions = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingOptions = false;
      });
    }
  }

  Future<void> _fetchUnits(String buildingId) async {
    try {
      final result =
          await ApiService.instance.get('/buildings/units?buildingId=$buildingId');
      final data = result['data'];
      List<UnitItem> units = [];
      if (data is List) {
        units = data
            .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      setState(() {
        _units = units;
        _selectedUnitId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final body = <String, dynamic>{
        'buildingId': _selectedBuildingId,
        'unitId': _selectedUnitId,
        'tenantName': _tenantNameController.text.trim(),
        'tenantEmail': _tenantEmailController.text.trim(),
        'tenantPhone': _tenantPhoneController.text.trim(),
        if (_rentController.text.trim().isNotEmpty)
          'monthlyRent': int.parse(_rentController.text.trim()),
        if (_depositController.text.trim().isNotEmpty)
          'deposit': int.parse(_depositController.text.trim()),
        if (_startDate != null)
          'startDate': _startDate!.toIso8601String(),
        if (_endDate != null)
          'endDate': _endDate!.toIso8601String(),
        if (_notesController.text.trim().isNotEmpty)
          'notes': _notesController.text.trim(),
        if (_termsController.text.trim().isNotEmpty)
          'terms': _termsController.text.trim(),
      };

      if (_isEditing && widget.lease!.id != null) {
        await ApiService.instance.patch('/leases/${widget.lease!.id}', body);
      } else {
        await ApiService.instance.post('/leases', body);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Bail mis à jour avec succès'
                : 'Bail créé avec succès'),
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le bail' : 'Nouveau bail'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchOptions,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Building selector
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBuildingId,
                          decoration: const InputDecoration(
                            labelText: 'Immeuble *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.apartment_outlined),
                          ),
                          items: _buildings.map((b) {
                            return DropdownMenuItem(
                              value: b.id,
                              child: Text(b.name,
                                  overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) {
                            setState(() => _selectedBuildingId = v);
                            if (v != null) _fetchUnits(v);
                          },
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 16),

                        // Unit selector (cascading)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Unité *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.door_front_door_outlined),
                          ),
                          items: _units.map((u) {
                            return DropdownMenuItem(
                              value: u.id,
                              child: Text(
                                '${u.number} — ${u.type} (${u.bedrooms}ch)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedUnitId = v),
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 24),

                        // Section: Tenant info
                        const Text(
                          'Informations du locataire',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _tenantNameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom complet *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Requis' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tenantEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Courriel',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tenantPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Téléphone',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 24),

                        // Section: Lease terms
                        const Text(
                          'Conditions du bail',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Start date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _startDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de début',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _startDate != null
                                  ? DateFormat('d MMMM yyyy', 'fr_CA')
                                      .format(_startDate!)
                                  : 'Sélectionner une date',
                              style: TextStyle(
                                color: _startDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // End date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ??
                                  (_startDate ?? DateTime.now())
                                      .add(const Duration(days: 365)),
                              firstDate: _startDate ?? DateTime.now(),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() => _endDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date de fin',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.event_outlined),
                              suffixIcon: Icon(Icons.arrow_drop_down),
                            ),
                            child: Text(
                              _endDate != null
                                  ? DateFormat('d MMMM yyyy', 'fr_CA')
                                      .format(_endDate!)
                                  : 'Sélectionner une date',
                              style: TextStyle(
                                color: _endDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rent and deposit
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _rentController,
                                decoration: const InputDecoration(
                                  labelText: 'Loyer (¢)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.attach_money),
                                  hintText: 'Ex: 95000',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _depositController,
                                decoration: const InputDecoration(
                                  labelText: 'Dépôt (¢)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.savings_outlined),
                                  hintText: 'Ex: 95000',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Terms
                        TextFormField(
                          controller: _termsController,
                          decoration: const InputDecoration(
                            labelText: 'Conditions',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description_outlined),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),

                        // Notes
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.notes_outlined),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),

                        // Submit button
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  _isEditing
                                      ? 'Enregistrer'
                                      : 'Créer le bail',
                                  style: const TextStyle(
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
