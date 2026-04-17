import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';

class PaymentDetailScreen extends StatelessWidget {
  const PaymentDetailScreen({super.key, required this.payment});

  final PaymentItem payment;

  String _formatCents(int cents) {
    final dollars = (cents / 100).toStringAsFixed(2);
    return '$dollars \$';
  }

  @override
  Widget build(BuildContext context) {
    final status = payment.status;
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Paiement — ${payment.unitLabel}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: status.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    status == PaymentStatus.paid
                        ? Icons.check_circle
                        : status == PaymentStatus.late
                            ? Icons.warning_amber
                            : status == PaymentStatus.pending
                                ? Icons.schedule
                                : status == PaymentStatus.partial
                                    ? Icons.remove_circle
                                    : Icons.error,
                    color: status.color,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: AppTypography.pageTitle.copyWith(
                          color: status.color,
                          fontSize: 20,
                        ),
                      ),
                      if (payment.periodLabel.isNotEmpty)
                        Text(
                          payment.periodLabel,
                          style: AppTypography.caption.copyWith(
                            color: status.color.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Tenant & unit info
            _buildInfoCard(
              children: [
                _buildInfoRow(
                  icon: Icons.person_outline,
                  label: 'Locataire',
                  value: payment.tenantName.isNotEmpty
                      ? payment.tenantName
                      : 'Non renseigné',
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.door_front_door_outlined,
                  label: 'Unité',
                  value: payment.unitLabel,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.apartment,
                  label: 'Immeuble',
                  value: payment.buildingName,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Payment amounts
            _buildInfoCard(
              children: [
                const Text('Montants', style: AppTypography.sectionHeader),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.attach_money,
                  label: 'Montant dû',
                  value: _formatCents(payment.amount),
                  valueColor: AppColors.textPrimary,
                ),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.payment_outlined,
                  label: 'Montant payé',
                  value: _formatCents(payment.amountPaid),
                  valueColor: AppColors.success,
                ),
                if (payment.outstanding > 0) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow(
                    icon: Icons.error_outline,
                    label: 'Solde restant',
                    value: _formatCents(payment.outstanding),
                    valueColor: AppColors.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: payment.amount > 0
                        ? payment.amountPaid / payment.amount
                        : 0.0,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.success),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${payment.amount > 0 ? ((payment.amountPaid / payment.amount * 100).toStringAsFixed(0)) : '0'}% payé',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Dates
            _buildInfoCard(
              children: [
                const Text('Dates', style: AppTypography.sectionHeader),
                const SizedBox(height: AppSpacing.md),
                _buildInfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date d\'échéance',
                  value: payment.dueDate,
                ),
                if (payment.paidAt.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow(
                    icon: Icons.check_circle_outline,
                    label: 'Date de paiement',
                    value: payment.paidAt,
                    valueColor: AppColors.success,
                  ),
                ],
                if (payment.method.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  _buildInfoRow(
                    icon: Icons.credit_card_outlined,
                    label: 'Méthode',
                    value: _methodLabel(payment.method),
                  ),
                ],
              ],
            ),

            if (payment.notes != null && payment.notes!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _buildInfoCard(
                children: [
                  const Text('Notes', style: AppTypography.sectionHeader),
                  const SizedBox(height: AppSpacing.sm),
                  Text(payment.notes!, style: AppTypography.body),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: AppTypography.body),
        const Spacer(),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _methodLabel(String method) {
    switch (method.toLowerCase()) {
      case 'credit_card':
      case 'carte_credit':
        return 'Carte de crédit';
      case 'debit':
      case 'debit_card':
      case 'carte_debit':
        return 'Carte de débit';
      case 'transfer':
      case 'virement':
        return 'Virement bancaire';
      case 'cash':
      case 'especes':
        return 'Espèces';
      case 'e_transfer':
      case 'interac':
        return 'Interac';
      case 'cheque':
        return 'Chèque';
      default:
        return method;
    }
  }
}
