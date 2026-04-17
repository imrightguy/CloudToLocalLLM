import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class _UnitEntry {
  final TextEditingController numberController;
  final TextEditingController typeController;
  final TextEditingController bedroomsController;
  final TextEditingController rentController;

  _UnitEntry({
    required this.numberController,
    required this.typeController,
    required this.bedroomsController,
    required this.rentController,
  });

  Map<String, dynamic> toMap() => {
        'label': numberController.text.trim(),
        'type': typeController.text.trim().isEmpty ? 'Studio' : typeController.text.trim(),
        'bedrooms': int.tryParse(bedroomsController.text.trim()) ?? 1,
        'rentCents': int.tryParse(rentController.text.trim()) ?? 80000,
        'status': 'available',
      };

  void dispose() {
    numberController.dispose();
    typeController.dispose();
    bedroomsController.dispose();
    rentController.dispose();
  }
}

class OnboardingUnitsStep extends StatefulWidget {
  final String buildingId;
  final String buildingName;
  final int totalUnits;
  final void Function(List<Map<String, dynamic>> units) onAdded;

  const OnboardingUnitsStep({
    super.key,
    required this.buildingId,
    required this.buildingName,
    required this.totalUnits,
    required this.onAdded,
  });

  @override
  State<OnboardingUnitsStep> createState() => _OnboardingUnitsStepState();
}

class _OnboardingUnitsStepState extends State<OnboardingUnitsStep> {
  final _formKey = GlobalKey<FormState>();
  late List<_UnitEntry> _entries;

  @override
  void initState() {
    super.initState();
    final count = widget.totalUnits.clamp(1, 50);
    _entries = List.generate(
      count,
      (i) => _UnitEntry(
        numberController: TextEditingController(text: '${i + 1}'),
        typeController: TextEditingController(),
        bedroomsController: TextEditingController(text: '1'),
        rentController: TextEditingController(text: '800'),
      ),
    );
  }

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final units = _entries.map((e) => e.toMap()).toList();
    widget.onAdded(units);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            'Ajoutez les unités pour ${widget.buildingName}.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Form(
            key: _formKey,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: _entries.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: AppSpacing.cardDecoration(
                    color: AppColors.surfaceVariant,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.door_front_door_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Unité ${index + 1}',
                            style: AppTypography.sectionHeader.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: entry.numberController,
                        decoration: const InputDecoration(
                          labelText: 'Numéro *',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.tag, size: 18),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Requis' : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: entry.typeController,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                isDense: true,
                                hintText: 'Studio, 4½…',
                                prefixIcon: Icon(Icons.category_outlined, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: entry.bedroomsController,
                              decoration: const InputDecoration(
                                labelText: 'Ch.',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.bed_outlined, size: 18),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SizedBox(
                            width: 120,
                            child: TextFormField(
                              controller: entry.rentController,
                              decoration: const InputDecoration(
                                labelText: 'Loyer (\$)',
                                border: OutlineInputBorder(),
                                isDense: true,
                                prefixIcon: Icon(Icons.attach_money, size: 18),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: const Text(
                'Confirmer les unités',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
