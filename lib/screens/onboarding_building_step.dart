import 'package:flutter/material.dart';

import '../services/building_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class OnboardingBuildingStep extends StatefulWidget {
  final void Function(String buildingId, int totalUnits) onCreated;
  final String initialName;
  final String initialAddress;
  final String initialCity;

  const OnboardingBuildingStep({
    super.key,
    required this.onCreated,
    this.initialName = '',
    this.initialAddress = '',
    this.initialCity = 'Montréal',
  });

  @override
  State<OnboardingBuildingStep> createState() => _OnboardingBuildingStepState();
}

class _OnboardingBuildingStepState extends State<OnboardingBuildingStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _totalUnitsController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _addressController = TextEditingController(text: widget.initialAddress);
    _cityController = TextEditingController(text: widget.initialCity);
    _postalCodeController = TextEditingController();
    _totalUnitsController = TextEditingController(
      text: widget.totalUnits > 0 ? widget.totalUnits.toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final building = await BuildingService.instance.createBuilding({
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim().isEmpty
            ? 'Montréal'
            : _cityController.text.trim(),
        'province': 'QC',
        if (_postalCodeController.text.trim().isNotEmpty)
          'postalCode': _postalCodeController.text.trim(),
        'totalUnits': int.parse(_totalUnitsController.text.trim()),
      });

      if (mounted) {
        final totalUnits = int.parse(_totalUnitsController.text.trim());
        widget.onCreated(building.id, totalUnits);
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Commencez par ajouter votre premier immeuble.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
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
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.lg),
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
                    initialValue: 'QC',
                    enabled: false,
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
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.xl * 2),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
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
    );
  }
}
