import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';

class VisitDetailScreen extends StatelessWidget {
  const VisitDetailScreen({super.key, required this.visit});

  final VisitItem visit;

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(visit.status);
    final timeLabel = visit.dateTime != null
        ? DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(visit.dateTime!)
        : visit.dateLabel;

    return Scaffold(
      appBar: const ImmoAppBar(title: 'Détails de la visite'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppSpacing.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visite du $timeLabel',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    statusLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppSpacing.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Immeuble', visit.buildingName),
                  _detailRow('Unité', visit.unitLabel),
                  _detailRow('Agent', visit.agent),
                  if (visit.leadName != null && visit.leadName!.isNotEmpty)
                    _detailRow('Prospect', visit.leadName!),
                  _detailRow('Statut', statusLabel),
                  if (visit.notes.isNotEmpty) _detailRow('Notes', visit.notes),
                  if (visit.tenantConfirmationRequestedAt != null)
                    _detailRow('Confirmation locataire demandée', _formatTimestamp(visit.tenantConfirmationRequestedAt!)),
                  if (visit.tenantConfirmedAt != null)
                    _detailRow('Locataire confirmé le', _formatTimestamp(visit.tenantConfirmedAt!)),
                  if (visit.tenantDeclinedAt != null)
                    _detailRow('Locataire a refusé le', _formatTimestamp(visit.tenantDeclinedAt!)),
                  if (visit.employeeConfirmationRequestedAt != null)
                    _detailRow('Confirmation employé demandée', _formatTimestamp(visit.employeeConfirmationRequestedAt!)),
                  if (visit.employeeConfirmedAt != null)
                    _detailRow('Employé confirmé le', _formatTimestamp(visit.employeeConfirmedAt!)),
                  if (visit.employeeDeclinedAt != null)
                    _detailRow('Employé a refusé le', _formatTimestamp(visit.employeeDeclinedAt!)),
                  if (visit.morningReminderSentAt != null)
                    _detailRow('Rappel du matin envoyé le', _formatTimestamp(visit.morningReminderSentAt!)),
                  if (visit.reminder24hQueuedAt != null)
                    _detailRow('Rappel 24h planifié le', _formatTimestamp(visit.reminder24hQueuedAt!)),
                  if (visit.reminder2hQueuedAt != null)
                    _detailRow('Rappel 2h planifié le', _formatTimestamp(visit.reminder2hQueuedAt!)),
                  _detailRow('Préavis rappel matin', visit.morningOfSent ? 'Oui' : 'Non'),
                  const SizedBox(height: 8),
                  _occupantStatusRow(),
                  _detailRow('Employé confirmé', visit.employeeConfirmed ? 'Oui' : 'Non'),
                  if (visit.outcome != null && visit.outcome!.isNotEmpty)
                    _detailRow('Résultat', visit.outcome!),
                  if (visit.reasonCode != null && visit.reasonCode!.isNotEmpty)
                    _detailRow('Code de raison', visit.reasonCode!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label :',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _occupantStatusRow() {
    if (!visit.occupantNotified && !visit.tenantConfirmed) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.notifications_none, size: 16, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Locataire non notifié',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (visit.tenantConfirmed) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 16, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Locataire notifié et confirmé',
              style: TextStyle(fontSize: 13, color: AppColors.success),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: AppColors.warning),
          SizedBox(width: 6),
          Text(
            'Locataire notifié en attente',
            style: TextStyle(fontSize: 13, color: AppColors.warning),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return DateFormat('d MMM yyyy à HH:mm', 'fr').format(dateTime);
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      case 'no_show':
        return 'Absent';
      case 'scheduled':
        return 'Planifiée';
      default:
        return status;
    }
  }
}
