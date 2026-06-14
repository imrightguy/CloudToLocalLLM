import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/maintenance_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';

class MaintenanceTicketDetailScreen extends StatefulWidget {
  const MaintenanceTicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<MaintenanceTicketDetailScreen> createState() =>
      _MaintenanceTicketDetailScreenState();
}

class _MaintenanceTicketDetailScreenState
    extends State<MaintenanceTicketDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  MaintenanceTicket? _ticket;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _fetchTicket();
  }

  Future<void> _fetchTicket() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ticket = await MaintenanceService.instance.getTicket(widget.ticketId);
      setState(() {
        _ticket = ticket;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final updated = await MaintenanceService.instance
          .updateTicket(widget.ticketId, {'status': status});
      setState(() {
        _ticket = updated;
        _changed = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Statut: ${updated.statusLabel}'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolu':
        return AppColors.success;
      case 'en_cours':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  Color _urgencyColor(String urgency) {
    switch (urgency) {
      case 'urgence':
        return AppColors.error;
      case 'haute':
        return AppColors.warning;
      case 'basse':
        return AppColors.info;
      default:
        return AppColors.skyBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: ImmoAppBar(
          title: 'Ticket',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null || _ticket == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'Ticket introuvable',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchTicket,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final ticket = _ticket!;
    final createdLabel = ticket.createdAt != null
        ? DateFormat('d MMMM yyyy à HH:mm', 'fr').format(ticket.createdAt!)
        : '—';
    final resolvedLabel = ticket.resolvedAt != null
        ? DateFormat('d MMMM yyyy à HH:mm', 'fr').format(ticket.resolvedAt!)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _badge(ticket.statusLabel, _statusColor(ticket.status)),
              _badge(ticket.urgencyLabel, _urgencyColor(ticket.urgency)),
              if (ticket.source == 'vapi') _badge('Vapi', AppColors.info),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (ticket.description.isNotEmpty) ...[
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(ticket.description,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.lg),
          ],
          _infoRow('Locataire', ticket.tenantName.isNotEmpty ? ticket.tenantName : '—'),
          _infoRow('Téléphone', ticket.callerPhone.isNotEmpty ? ticket.callerPhone : '—'),
          _infoRow('Source', ticket.source),
          _infoRow('Créé le', createdLabel),
          if (resolvedLabel != null) _infoRow('Résolu le', resolvedLabel),
          const SizedBox(height: AppSpacing.lg),
          if (ticket.photos.isNotEmpty) ...[
            const Text('Photos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: ticket.photos
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: Image.network(
                          url,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 100,
                            height: 100,
                            color: AppColors.surfaceVariant,
                            child: const Icon(Icons.broken_image_outlined,
                                color: AppColors.textMuted),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const Text('Changer le statut', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              _statusButton('ouvert', 'Ouvert', ticket.status),
              _statusButton('en_cours', 'En cours', ticket.status),
              _statusButton('resolu', 'Résolu', ticket.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(String value, String label, String current) {
    final isCurrent = value == current;
    return isCurrent
        ? FilledButton(onPressed: null, child: Text(label))
        : OutlinedButton(
            onPressed: () => _updateStatus(value),
            child: Text(label),
          );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}
