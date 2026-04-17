import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class OnboardingInviteStep extends StatefulWidget {
  final String buildingName;
  final VoidCallback onComplete;
  final VoidCallback onSkipped;

  const OnboardingInviteStep({
    super.key,
    required this.buildingName,
    required this.onComplete,
    required this.onSkipped,
  });

  @override
  State<OnboardingInviteStep> createState() => _OnboardingInviteStepState();
}

class _OnboardingInviteStepState extends State<OnboardingInviteStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ApiService.instance.post('/invitations', {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'channel': 'sms',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation envoyée avec succès !'),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onComplete();
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
              'Invitez un locataire pour ${widget.buildingName} par SMS.',
              style:
                  AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: AppSpacing.cardDecoration(
                color: AppColors.primarySurface,
              ),
              child: Row(
                children: [
                  const Icon(Icons.sms_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Un lien de connexion sera envoyé au locataire par SMS.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du locataire *',
                hintText: 'Ex: Jean Dupont',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Nom requis'
                  : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone *',
                hintText: 'Ex: (514) 555-1234',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                final digits = v.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
                if (digits.length < 10) return 'Numéro invalide (min 10 chiffres)';
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
                      'Envoyer l\'invitation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _isSubmitting ? null : widget.onSkipped,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: const Text('Passer cette étape'),
            ),
          ],
        ),
      ),
    );
  }
}
