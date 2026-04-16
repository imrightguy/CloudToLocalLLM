import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import 'lease_form_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';

class LeaseDetailScreen extends StatefulWidget {
  const LeaseDetailScreen({
    super.key,
    required this.lease,
    required this.onLeaseChanged,
  });

  final LeaseItem lease;
  final VoidCallback onLeaseChanged;

  @override
  State<LeaseDetailScreen> createState() => _LeaseDetailScreenState();
}

class _LeaseDetailScreenState extends State<LeaseDetailScreen> {
  late LeaseItem _lease;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lease = widget.lease;
  }

  Future<void> _sendToTenant() async {
    if (_lease.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer le bail au locataire?'),
        content: Text(
            'Le bail sera envoyé à ${_lease.tenantName ?? 'N/A'} (${_lease.tenantEmail ?? 'N/A'}).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.patch('/leases/${_lease.id}/status', {'status': 'sent'});
      setState(() => _lease = LeaseItem(
            id: _lease.id,
            buildingId: _lease.buildingId,
            buildingName: _lease.buildingName,
            unitId: _lease.unitId,
            unitLabel: _lease.unitLabel,
            tenantName: _lease.tenantName,
            tenantEmail: _lease.tenantEmail,
            tenantPhone: _lease.tenantPhone,
            startDate: _lease.startDate,
            endDate: _lease.endDate,
            monthlyRent: _lease.monthlyRent,
            deposit: _lease.deposit,
            status: LeaseStatus.sent,
            notes: _lease.notes,
            terms: _lease.terms,
            createdAt: _lease.createdAt,
            updatedAt: _lease.updatedAt,
          ));
      widget.onLeaseChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bail envoyé au locataire'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsSigned() async {
    if (_lease.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Marquer comme signé?'),
        content: const Text('Confirmez que le bail a été signé par le locataire.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Signer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.patch('/leases/${_lease.id}/sign', {});
      setState(() => _lease = LeaseItem(
            id: _lease.id,
            buildingId: _lease.buildingId,
            buildingName: _lease.buildingName,
            unitId: _lease.unitId,
            unitLabel: _lease.unitLabel,
            tenantName: _lease.tenantName,
            tenantEmail: _lease.tenantEmail,
            tenantPhone: _lease.tenantPhone,
            startDate: _lease.startDate,
            endDate: _lease.endDate,
            monthlyRent: _lease.monthlyRent,
            deposit: _lease.deposit,
            status: LeaseStatus.signed,
            notes: _lease.notes,
            terms: _lease.terms,
            createdAt: _lease.createdAt,
            updatedAt: _lease.updatedAt,
          ));
      widget.onLeaseChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bail marqué comme signé'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _terminateLease() async {
    if (_lease.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résilier le bail?'),
        content: Text(
            'Voulez-vous vraiment résilier le bail de ${_lease.tenantName ?? ''}? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Résilier'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.patch('/leases/${_lease.id}/status', {'status': 'terminated'});
      setState(() => _lease = LeaseItem(
            id: _lease.id,
            buildingId: _lease.buildingId,
            buildingName: _lease.buildingName,
            unitId: _lease.unitId,
            unitLabel: _lease.unitLabel,
            tenantName: _lease.tenantName,
            tenantEmail: _lease.tenantEmail,
            tenantPhone: _lease.tenantPhone,
            startDate: _lease.startDate,
            endDate: _lease.endDate,
            monthlyRent: _lease.monthlyRent,
            deposit: _lease.deposit,
            status: LeaseStatus.terminated,
            notes: _lease.notes,
            terms: _lease.terms,
            createdAt: _lease.createdAt,
            updatedAt: _lease.updatedAt,
          ));
      widget.onLeaseChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bail résilié'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _lease.leaseStatus.color;

    return Scaffold(
      appBar: ImmoAppBar(title: 'Détails du bail', actions: [
          if (_lease.leaseStatus == LeaseStatus.draft)
            IconButton(
              onPressed: () {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => LeaseFormScreen(lease: _lease),
                    fullscreenDialog: true,
                  ),
                )
                    .then((_) {
                  if (mounted) widget.onLeaseChanged();
                });
              },
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
            ),
        ]),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(statusColor),
                  const SizedBox(height: 16),
                  _buildStatusTimeline(statusColor),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Informations'),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Locataire'),
                  const SizedBox(height: 8),
                  _buildTenantCard(),
                  if (_lease.notes != null && _lease.notes!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Notes'),
                    const SizedBox(height: 8),
                    _buildNotesCard(),
                  ],
                  const SizedBox(height: 32),
                  _buildActionButtons(statusColor),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          AppSpacing.elevationCard,
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: statusColor.withOpacity( 0.1),
            child: Icon(
              _lease.leaseStatus.icon,
              size: 28,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lease.tenantName ?? 'Sans locataire',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_lease.unitLabel ?? ''} — ${_lease.buildingName ?? ''}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity( 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _lease.leaseStatus.label,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(Color currentColor) {
    const stages = LeaseStatus.values;
    final currentIdx = _lease.leaseStatus.orderIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cycle de vie du bail',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(stages.length, (i) {
              final isPast = i < currentIdx;
              final isActive = i == currentIdx;
              final stageColor = stages[i].color;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: isActive ? 16 : 12,
                          height: isActive ? 16 : 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPast || isActive
                                ? stageColor
                                : AppColors.border,
                            border: isActive
                                ? Border.all(
                                    color: stageColor,
                                    width: 3,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 56,
                          child: Text(
                            stages[i].label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9,
                              color: isPast || isActive
                                  ? stageColor
                                  : AppColors.textMuted,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (i < stages.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 18),
                          color: isPast
                              ? AppColors.success
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        children: [
          _infoRow(Icons.apartment_outlined, 'Immeuble', _lease.buildingName ?? '--'),
          const Divider(height: 24),
          _infoRow(Icons.door_front_door_outlined, 'Unité', _lease.unitLabel ?? '--'),
          const Divider(height: 24),
          _infoRow(Icons.attach_money_outlined, 'Loyer mensuel', _lease.displayRent),
          const Divider(height: 24),
          _infoRow(Icons.savings_outlined, 'Dépôt de garantie', _lease.displayDeposit),
          const Divider(height: 24),
          _infoRow(Icons.calendar_today_outlined, 'Début', _lease.displayStartDate),
          const Divider(height: 24),
          _infoRow(Icons.event_outlined, 'Fin', _lease.displayEndDate),
          if (_lease.terms != null && _lease.terms!.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.description_outlined, 'Conditions', _lease.terms!),
          ],
        ],
      ),
    );
  }

  Widget _buildTenantCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        children: [
          _infoRow(Icons.person_outline, 'Nom', _lease.tenantName ?? '--'),
          const Divider(height: 24),
          _infoRow(Icons.email_outlined, 'Courriel', _lease.tenantEmail ?? '--'),
          const Divider(height: 24),
          _infoRow(Icons.phone_outlined, 'Téléphone', _lease.tenantPhone ?? '--'),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Text(
        _lease.notes!,
        style: const TextStyle(fontSize: 14, color: AppColors.label),
      ),
    );
  }

  Widget _buildActionButtons(Color statusColor) {
    final status = _lease.leaseStatus;

    if (status == LeaseStatus.draft) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : _sendToTenant,
        icon: const Icon(Icons.send_outlined, size: 18),
        label: const Text('Envoyer au locataire'),
        style: ElevatedButton.styleFrom(
          backgroundColor: statusColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (status == LeaseStatus.sent) {
      return ElevatedButton.icon(
        onPressed: _isLoading ? null : _markAsSigned,
        icon: const Icon(Icons.draw_outlined, size: 18),
        label: const Text('Marquer comme signé'),
        style: ElevatedButton.styleFrom(
          backgroundColor: statusColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (status == LeaseStatus.active) {
      return OutlinedButton.icon(
        onPressed: _isLoading ? null : _terminateLease,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Résilier le bail'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
