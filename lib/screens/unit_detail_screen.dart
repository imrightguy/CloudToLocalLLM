import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';

class UnitDetailScreen extends StatelessWidget {
  const UnitDetailScreen({super.key, required this.unit});

  final UnitItem unit;

  @override
  Widget build(BuildContext context) {
    final vacancy = unit.vacancyStatus;
    final tenantLabel = unit.tenantName ?? unit.tenant;

    return Scaffold(
      appBar: ImmoAppBar(title: 'Unité ${unit.number}'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: vacancy.color.withOpacity( 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _vacancyIcon(vacancy),
                    color: vacancy.color,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vacancy.label,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: vacancy.color,
                        ),
                      ),
                      if (unit.type.isNotEmpty)
                        Text(
                          unit.type,
                          style: TextStyle(
                            fontSize: 14,
                            color: vacancy.color.withOpacity( 0.8),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Rent and specs
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
                    const Text(
                      'Détails',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      icon: Icons.attach_money,
                      label: 'Loyer',
                      value: '${unit.rent}\$ / mois',
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    if (unit.bedrooms > 0)
                      _buildDetailRow(
                        icon: Icons.bed_outlined,
                        label: 'Chambres',
                        value: '${unit.bedrooms}',
                      ),
                    if (unit.bedrooms > 0) const SizedBox(height: 12),
                    if (unit.bathrooms > 0)
                      _buildDetailRow(
                        icon: Icons.bathtub_outlined,
                        label: 'Salles de bain',
                        value: '${unit.bathrooms}',
                      ),
                    if (unit.bathrooms > 0) const SizedBox(height: 12),
                    if (unit.squareFeet != null && unit.squareFeet! > 0)
                      _buildDetailRow(
                        icon: Icons.square_foot,
                        label: 'Superficie',
                        value: '${unit.squareFeet} pi²',
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Tenant information
            if (tenantLabel != null && tenantLabel.isNotEmpty) ...[
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
                      Row(
                        children: [
                          const Icon(Icons.person,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Locataire',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        icon: Icons.person_outline,
                        label: 'Nom',
                        value: tenantLabel,
                      ),
                      const SizedBox(height: 12),
                      if (unit.tenantPhone != null &&
                          unit.tenantPhone!.isNotEmpty)
                        _buildDetailRow(
                          icon: Icons.phone_outlined,
                          label: 'Téléphone',
                          value: unit.tenantPhone!,
                        ),
                      if (unit.tenantPhone != null &&
                          unit.tenantPhone!.isNotEmpty)
                        const SizedBox(height: 12),
                      if (unit.tenantLeaseEnd != null)
                        _buildDetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Fin de bail',
                          value: DateFormat('d MMMM yyyy', 'fr_CA')
                              .format(unit.tenantLeaseEnd!),
                          valueColor: _leaseEndColor(unit.tenantLeaseEnd!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Amenities
            if (unit.amenities != null && unit.amenities!.isNotEmpty) ...[
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
                      Row(
                        children: [
                          const Icon(Icons.checklist,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Commodités',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: unit.amenities!.map((amenity) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withOpacity( 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _amenityLabel(amenity),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _vacancyIcon(VacancyStatus status) {
    switch (status) {
      case VacancyStatus.vacant:
        return Icons.vacuum_outlined;
      case VacancyStatus.occupied:
        return Icons.check_circle_outline;
      case VacancyStatus.maintenance:
        return Icons.build_outlined;
    }
  }

  Color _leaseEndColor(DateTime leaseEnd) {
    final now = DateTime.now();
    final threeMonths = now.add(const Duration(days: 90));
    if (leaseEnd.isBefore(now)) return AppColors.error;
    if (leaseEnd.isBefore(threeMonths)) return AppColors.warning;
    return AppColors.success;
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _amenityLabel(String key) {
    final labels = {
      'fridge': 'Réfrigérateur',
      'stove': 'Cuisinière',
      'dishwasher': 'Lave-vaisselle',
      'washer': 'Laveuse',
      'dryer': 'Sécheuse',
      'microwave': 'Four micro-ondes',
      'ac': 'Climatisation',
      'heating': 'Chauffage',
      'parking': 'Stationnement',
      'storage': 'Entreposage',
      'balcony': 'Balcon',
      'elevator': 'Ascenseur',
      'pool': 'Piscine',
      'gym': 'Salle de sport',
      'concierge': 'Concierge',
    };
    return labels[key.toLowerCase()] ?? key;
  }
}
