import 'package:flutter/material.dart';

import '../models.dart';
import '../services/property_photo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class PropertyPhotoUploadSheet extends StatefulWidget {
  const PropertyPhotoUploadSheet({
    super.key,
    required this.initialBuildingName,
    required this.initialUnitLabel,
    required this.contextSource,
    required this.photoUploader,
    required this.photoPicker,
    this.apartmentLabel,
  });

  final String initialBuildingName;
  final String initialUnitLabel;
  final String? apartmentLabel;
  final PropertyPhotoContextSource contextSource;
  final PropertyPhotoUploader photoUploader;
  final PhotoPicker photoPicker;

  @override
  State<PropertyPhotoUploadSheet> createState() => _PropertyPhotoUploadSheetState();
}

class _PropertyPhotoUploadSheetState extends State<PropertyPhotoUploadSheet> {
  final TextEditingController _roomContextController = TextEditingController();
  final TextEditingController _displayOrderController = TextEditingController(text: '0');

  bool _loadingContext = true;
  bool _loadingUnits = false;
  bool _uploading = false;
  String? _errorMessage;
  PickedPhoto? _pickedPhoto;
  List<BuildingItem> _buildings = const [];
  List<UnitItem> _units = const [];
  String? _selectedBuildingId;
  String? _selectedUnitId;
  String _selectedUseCase = 'maintenance';

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  @override
  void dispose() {
    _roomContextController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  Future<void> _loadBuildings() async {
    try {
      final buildings = await widget.contextSource.getBuildings();
      if (!mounted) {
        return;
      }

      String? selectedBuildingId;
      if (widget.initialBuildingName.isNotEmpty) {
        for (final building in buildings) {
          if (building.name.trim().toLowerCase() == widget.initialBuildingName.trim().toLowerCase()) {
            selectedBuildingId = building.id;
            break;
          }
        }
      }
      selectedBuildingId ??= buildings.isNotEmpty ? buildings.first.id : null;

      setState(() {
        _buildings = buildings;
        _selectedBuildingId = selectedBuildingId;
        _loadingContext = false;
        _errorMessage = buildings.isEmpty ? 'Aucun bâtiment disponible pour téléverser une photo.' : null;
      });

      if (_selectedBuildingId != null) {
        await _loadUnits(_selectedBuildingId!, selectByLabel: true);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _loadingContext = false;
      });
    }
  }

  Future<void> _loadUnits(String buildingId, {bool selectByLabel = false}) async {
    setState(() {
      _loadingUnits = true;
      _selectedUnitId = null;
      _units = const [];
    });

    try {
      final units = await widget.contextSource.getUnitsByBuilding(buildingId);
      if (!mounted) {
        return;
      }

      String? selectedUnitId;
      if (selectByLabel && widget.initialUnitLabel.isNotEmpty) {
        for (final unit in units) {
          if (unit.number.trim().toLowerCase() == widget.initialUnitLabel.trim().toLowerCase()) {
            selectedUnitId = unit.id;
            break;
          }
        }
      }
      selectedUnitId ??= units.isNotEmpty ? units.first.id : null;

      setState(() {
        _units = units;
        _selectedUnitId = selectedUnitId;
        _loadingUnits = false;
        if (units.isEmpty) {
          _errorMessage = 'Aucun logement trouvé pour ce bâtiment.';
        } else {
          _errorMessage = null;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingUnits = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await widget.photoPicker.pickPhoto();
    if (!mounted || photo == null) {
      return;
    }
    setState(() {
      _pickedPhoto = photo;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final buildingId = _selectedBuildingId;
    if (buildingId == null || _pickedPhoto == null) {
      setState(() {
        _errorMessage = 'Choisissez un bâtiment, un logement et une photo avant de téléverser.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _errorMessage = null;
    });

    try {
      BuildingItem? building;
      for (final item in _buildings) {
        if (item.id == buildingId) {
          building = item;
          break;
        }
      }

      UnitItem? selectedUnit;
      for (final item in _units) {
        if (item.id == _selectedUnitId) {
          selectedUnit = item;
          break;
        }
      }
      await widget.photoUploader.uploadPhoto(
        companyId: propertyPhotoCompanyId,
        buildingId: buildingId,
        unitId: _selectedUnitId,
        fileBytes: _pickedPhoto!.bytes,
        fileName: _pickedPhoto!.fileName,
        fileType: _pickedPhoto!.fileType,
        roomContext: _roomContextController.text.trim().isEmpty ? null : _roomContextController.text.trim(),
        useCase: _selectedUseCase,
        displayOrder: int.tryParse(_displayOrderController.text.trim()) ?? 0,
        capturedAt: DateTime.now().toUtc(),
        metadata: {
          'source': 'frontend_operator',
          'surface': 'renovation_ops',
          'apartmentLabel': widget.apartmentLabel,
          'buildingName': building?.name,
          'buildingAddress': building?.address,
          'unitNumber': selectedUnit?.number,
        }..removeWhere((key, value) => value == null),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _uploading = false;
        _errorMessage = error.toString();
      });
    }
  }

  BuildingItem? _selectedBuilding() {
    for (final building in _buildings) {
      if (building.id == _selectedBuildingId) {
        return building;
      }
    }
    return null;
  }

  UnitItem? _selectedUnit() {
    for (final unit in _units) {
      if (unit.id == _selectedUnitId) {
        return unit;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final building = _selectedBuilding();
    final unit = _selectedUnit();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Téléverser une photo terrain',
                style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'La photo sera reliée au bâtiment, au logement et au contexte de travaux avant d\'être envoyée vers le backend.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
              if (widget.apartmentLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _ContextChip(label: widget.initialBuildingName.isEmpty ? 'Bâtiment' : widget.initialBuildingName),
                    _ContextChip(label: widget.initialUnitLabel.isEmpty ? 'Logement' : 'Logement ${widget.initialUnitLabel}'),
                    if (widget.apartmentLabel != null) _ContextChip(label: widget.apartmentLabel!),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_loadingContext)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedBuildingId,
                  decoration: const InputDecoration(
                    labelText: 'Bâtiment',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: _buildings
                      .map(
                        (building) => DropdownMenuItem(
                          value: building.id,
                          child: Text('${building.name} • ${building.city}'),
                        ),
                      )
                      .toList(),
                  onChanged: _uploading
                      ? null
                      : (value) {
                          if (value == null || value == _selectedBuildingId) {
                            return;
                          }
                          setState(() {
                            _selectedBuildingId = value;
                          });
                          _loadUnits(value);
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Logement',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  items: _units
                      .map(
                        (unit) => DropdownMenuItem(
                          value: unit.id,
                          child: Text('Logement ${unit.number} • ${unit.type}'),
                        ),
                      )
                      .toList(),
                  onChanged: _uploading || _loadingUnits
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedUnitId = value);
                          }
                        },
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUseCase,
                  decoration: const InputDecoration(
                    labelText: 'Usage',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                    DropdownMenuItem(value: 'marketing', child: Text('Marketing')),
                    DropdownMenuItem(value: 'inventory', child: Text('Inventaire')),
                  ],
                  onChanged: _uploading ? null : (value) {
                    if (value != null) {
                      setState(() => _selectedUseCase = value);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _roomContextController,
                  enabled: !_uploading,
                  decoration: const InputDecoration(
                    labelText: 'Contexte pièce',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.home_work_outlined),
                    hintText: 'Cuisine, salon, salle de bain…',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _displayOrderController,
                  enabled: !_uploading,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ordre d\'affichage',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.format_list_numbered),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (_loadingUnits)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
              InkWell(
                onTap: _uploading ? null : _pickPhoto,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: _pickedPhoto == null ? AppColors.surfaceVariant : AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: _pickedPhoto == null ? AppColors.border : AppColors.primary,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickedPhoto == null ? Icons.photo_camera_outlined : Icons.check_circle_rounded,
                        color: _pickedPhoto == null ? AppColors.textMuted : AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pickedPhoto?.fileName ?? 'Choisir une photo',
                              style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _pickedPhoto == null
                                  ? 'JPG, PNG, WebP ou GIF'
                                  : '${_pickedPhoto!.fileType} • ${_pickedPhoto!.bytes.length} octets',
                              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.body.copyWith(color: AppColors.error),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _uploading ? null : () => Navigator.of(context).pop(false),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : _submit,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(_uploading ? 'Téléversement…' : 'Téléverser la photo'),
                    ),
                  ),
                ],
              ),
              if (building != null || unit != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  [
                    if (building != null) building.address,
                    if (unit != null) 'Logement ${unit.number}',
                  ].join(' • '),
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      backgroundColor: AppColors.primarySurface,
      side: BorderSide.none,
    );
  }
}

