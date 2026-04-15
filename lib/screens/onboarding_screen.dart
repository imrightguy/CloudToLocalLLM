import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/building_service.dart';
import 'onboarding_building_step.dart';
import 'onboarding_units_step.dart';
import 'onboarding_invite_step.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class OnboardingData {
  String buildingId;
  final String buildingName;
  final String buildingAddress;
  final String buildingCity;
  final int totalUnits;
  final List<Map<String, dynamic>> units;

  OnboardingData({
    this.buildingId = '',
    required this.buildingName,
    required this.buildingAddress,
    required this.buildingCity,
    required this.totalUnits,
    List<Map<String, dynamic>>? units,
  }) : units = units ?? [];
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final OnboardingData _data = OnboardingData(
    buildingName: '',
    buildingAddress: '',
    buildingCity: 'Montréal',
    totalUnits: 0,
  );
  bool _isSubmitting = false;

  static const _stepTitles = [
    'Immeuble',
    'Unités',
    'Locataire',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _goToNext() async {
    if (_currentPage < _stepTitles.length - 1) {
      _pageController.nextPage();
      setState(() => _currentPage++);
    }
  }

  Future<void> _goToPrevious() async {
    if (_currentPage > 0) {
      _pageController.previousPage();
      setState(() => _currentPage--);
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      // Create units
      for (final unit in _data.units) {
        unit['buildingId'] = _data.buildingId;
        await BuildingService.instance.createUnit(
          _data.buildingId,
          unit,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration initiale terminée avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
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

  void _onBuildingCreated(String buildingId, int totalUnits) {
    setState(() {
      _data.buildingId = buildingId;
      _data.totalUnits = totalUnits;
    });
    _goToNext();
  }

  void _onUnitsAdded(List<Map<String, dynamic>> units) {
    setState(() {
      _data.units = units;
    });
    _goToNext();
  }

  void _onInviteSkipped() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: 'Configuration sauvegardée (sans invitation)'),
          backgroundColor: AppColors.info,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _onInviteComplete() {
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuration initiale'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _stepTitles.length; i++)
                      Container(
                        width: 60,
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i <= _currentPage
                              ? AppColors.primary
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _stepTitles[_currentPage],
                  style: AppTypography.sectionHeader
                      .copyWith(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Étape ${_currentPage + 1} sur ${_stepTitles.length}',
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Step content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              children: [
                OnboardingBuildingStep(
                  onCreated: _onBuildingCreated,
                  initialName: _data.buildingName,
                  initialAddress: _data.buildingAddress,
                  initialCity: _data.buildingCity,
                ),
                OnboardingUnitsStep(
                  buildingId: _data.buildingId,
                  buildingName: _data.buildingName,
                  totalUnits: _data.totalUnits,
                  onAdded: _onUnitsAdded,
                ),
                OnboardingInviteStep(
                  buildingName: _data.buildingName,
                  onComplete: _onInviteComplete,
                  onSkipped: _onInviteSkipped,
                ),
              ],
            ),
          ),
          // Navigation buttons
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : _goToPrevious,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                          ),
                        ),
                        child: const Text('Précédent'),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _goToNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      child: Text(
                        _currentPage < _stepTitles.length - 1
                            ? 'Suivant'
                            : 'Terminer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
