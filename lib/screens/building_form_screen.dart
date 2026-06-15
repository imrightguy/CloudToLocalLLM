import 'package:flutter/material.dart';

import '../models.dart';
import '../services/building_service.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-screen form for creating or editing a building.
class BuildingFormScreen extends StatefulWidget {
  const BuildingFormScreen({super.key, this.building});

  /// If non-null, edit an existing building.
  final BuildingItem? building;

  @override
  State<BuildingFormScreen> createState() => _BuildingFormScreenState();
}

class _BuildingFormScreenState extends State<BuildingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _yearBuiltController;

  bool _isSubmitting = false;
  String? _error;

  bool get _isEditing => widget.building != null;

  @override
  void initState() {
    super.initState();
    final b = widget.building;
    _nameController = TextEditingController(text: b?.name ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _cityController = TextEditingController(text: b?.city ?? '');
    _descriptionController = TextEditingController(text: b?.description ?? '');
    _postalCodeController =
        TextEditingController(text: b?.properties?['postalCode'] as String? ?? '');
    _yearBuiltController =
        TextEditingController(text: b?.properties?['yearBuilt']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _descriptionController.dispose();
    _postalCodeController.dispose();
    _yearBuiltController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      // Only include properties if at least one is provided.
      final properties = <String, dynamic>{};
      if (_postalCodeController.text.trim().isNotEmpty) {
        properties['postalCode'] = _postalCodeController.text.trim();
      }
      if (_yearBuiltController.text.trim().isNotEmpty) {
        properties['yearBuilt'] =
            int.tryParse(_yearBuiltController.text.trim());
      }
      if (properties.isNotEmpty) {
        data['properties'] = properties;
      }

      if (_isEditing) {
        await BuildingService.instance
            .updateBuilding(widget.building!.id!, data);
      } else {
        await BuildingService.instance.createBuilding(data);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message.isNotEmpty
            ? e.message
            : 'Erreur ${e.statusCode ?? ""} lors de l\'enregistrement.';
        _isSubmitting = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur réseau. Vérifiez votre connexion.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? "Modifier l'immeuble" : 'Nouvel immeuble'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Infos principales ──
              _sectionTitle('Informations générales'),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nom de l'immeuble *",
                  hintText: 'Ex: Le Château',
                  prefixIcon: Icon(Icons.apartment),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse *',
                  hintText: 'Ex: 1234 rue King Ouest',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ville *',
                        hintText: 'Ex: Sherbrooke',
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _postalCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Code postal',
                        hintText: 'J1H 1H1',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              _sectionTitle('Détails supplémentaires'),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Notes, caractéristiques, etc.',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _yearBuiltController,
                decoration: const InputDecoration(
                  labelText: 'Année de construction',
                  hintText: 'Ex: 1985',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Submit ──
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Enregistrer' : "Créer l'immeuble",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
