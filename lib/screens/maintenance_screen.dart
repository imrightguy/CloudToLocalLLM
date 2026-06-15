import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/maintenance_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';
import 'maintenance_ticket_detail.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MaintenanceTicket> _tickets = [];
  String? _statusFilter;

  static const _statuses = [
    {'value': 'ouvert', 'label': 'Ouvert'},
    {'value': 'en_cours', 'label': 'En cours'},
    {'value': 'resolu', 'label': 'Résolu'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final tickets =
          await MaintenanceService.instance.getTickets(status: _statusFilter, limit: 100);
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Tickets de maintenance',
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchTickets,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchTickets,
            child: _tickets.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Aucun ticket',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _tickets.length,
                    itemBuilder: (context, index) => _buildTicketCard(_tickets[index]),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _statusChip(null, 'Tous'),
            ..._statuses.map((s) => _statusChip(s['value'], s['label']!)),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String? value, String label) {
    final selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _statusFilter = value);
          _fetchTickets();
        },
      ),
    );
  }

  Widget _buildTicketCard(MaintenanceTicket ticket) {
    final createdLabel = ticket.createdAt != null
        ? DateFormat('d MMM yyyy, HH:mm', 'fr').format(ticket.createdAt!)
        : '';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: InkWell(
        onTap: () => _openDetail(ticket),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _badge(ticket.urgencyLabel, _urgencyColor(ticket.urgency)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _badge(ticket.statusLabel, _statusColor(ticket.status)),
                  const SizedBox(width: AppSpacing.sm),
                  if (ticket.source == 'vapi')
                    _badge('Vapi', AppColors.info),
                  const Spacer(),
                  if (ticket.photos.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.photo_outlined, size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Text('${ticket.photos.length}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                ],
              ),
              if (ticket.tenantName.isNotEmpty || ticket.callerPhone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  [ticket.tenantName, ticket.callerPhone].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              if (createdLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(createdLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _openDetail(MaintenanceTicket ticket) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MaintenanceTicketDetailScreen(ticketId: ticket.id),
      ),
    );
    if (changed == true && mounted) {
      _fetchTickets();
    }
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final phoneController = TextEditingController();
    String urgency = 'moyenne';

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nouveau ticket'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Titre'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Téléphone locataire'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: urgency,
                      decoration: const InputDecoration(labelText: 'Urgence'),
                      items: const [
                        DropdownMenuItem(value: 'basse', child: Text('Basse')),
                        DropdownMenuItem(value: 'moyenne', child: Text('Moyenne')),
                        DropdownMenuItem(value: 'haute', child: Text('Haute')),
                        DropdownMenuItem(value: 'urgence', child: Text('Urgence')),
                      ],
                      onChanged: (v) => setDialogState(() => urgency = v ?? 'moyenne'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.of(dialogContext).pop();
                    await _createTicket(
                      titleController.text.trim(),
                      descController.text.trim(),
                      phoneController.text.trim(),
                      urgency,
                    );
                  },
                  child: const Text('Créer'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleController.dispose();
      descController.dispose();
      phoneController.dispose();
    });
  }

  Future<void> _createTicket(
    String title,
    String description,
    String phone,
    String urgency,
  ) async {
    try {
      await MaintenanceService.instance.createTicket({
        'title': title,
        if (description.isNotEmpty) 'description': description,
        if (phone.isNotEmpty) 'callerPhone': phone,
        'urgency': urgency,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket créé'), backgroundColor: AppColors.success),
      );
      _fetchTickets();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
