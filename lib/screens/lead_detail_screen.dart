import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';

class LeadDetailScreen extends StatefulWidget {
  const LeadDetailScreen({
    super.key,
    required this.lead,
    required this.onStageChanged,
  });

  final LeadItem lead;
  final VoidCallback onStageChanged;

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late LeadItem _lead;
  bool _isLoading = false;
  bool _isEditing = false;

  late final TextEditingController _notesController;
  late final TextEditingController _budgetController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _desiredUnitController;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
    _notesController = TextEditingController(text: _lead.notes);
    _budgetController =
        TextEditingController(text: _lead.budget > 0 ? '${_lead.budget}' : '');
    _emailController = TextEditingController(text: _lead.email);
    _phoneController = TextEditingController(text: _lead.phone);
    _desiredUnitController = TextEditingController(text: _lead.desiredUnit);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _budgetController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _desiredUnitController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Stage advancement
  // ---------------------------------------------------------------------------

  LeadStage? get _nextStage {
    const stages = LeadStage.values;
    final idx = stages.indexOf(_lead.stage);
    if (idx < 0 || idx >= stages.length - 1) return null;
    return stages[idx + 1];
  }

  LeadStage? get _prevStage {
    const stages = LeadStage.values;
    final idx = stages.indexOf(_lead.stage);
    if (idx <= 0) return null;
    return stages[idx - 1];
  }

  Future<void> _moveToStage(LeadStage newStage) async {
    if (_lead.id == null) return;
    setState(() => _isLoading = true);
    try {
      await ApiService.instance
          .patch('/leads/${_lead.id}', {'stage': newStage.name});
      setState(() => _lead = LeadItem(
            id: _lead.id,
            language: _lead.language,
            createdAt: _lead.createdAt,
            fullName: _lead.fullName,
            email: _lead.email,
            phone: _lead.phone,
            desiredUnit: _lead.desiredUnit,
            budget: _lead.budget,
            source: _lead.source,
            stage: newStage,
            notes: _lead.notes,
            tags: _lead.tags,
            lastContact: _lead.lastContact,
            offers: _lead.offers,
          ));
      widget.onStageChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Prospect déplacé vers ${newStage.label}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Save edits
  // ---------------------------------------------------------------------------

  Future<void> _saveEdits() async {
    if (_lead.id == null) return;
    setState(() => _isLoading = true);
    try {
      final budgetText = _budgetController.text.trim();
      final body = <String, dynamic>{
        'notes': _notesController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'desiredUnit': _desiredUnitController.text.trim(),
      };
      if (budgetText.isNotEmpty) {
        body['budget'] = int.tryParse(budgetText) ?? _lead.budget;
      } else {
        body['budget'] = 0;
      }
      await ApiService.instance.patch('/leads/${_lead.id}', body);

      setState(() {
        _lead = LeadItem(
          id: _lead.id,
          language: _lead.language,
          createdAt: _lead.createdAt,
          fullName: _lead.fullName,
          email: body['email'] as String,
          phone: body['phone'] as String,
          desiredUnit: body['desiredUnit'] as String,
          budget: body['budget'] as int,
          source: _lead.source,
          stage: _lead.stage,
          notes: body['notes'] as String,
          tags: _lead.tags,
          lastContact: _lead.lastContact,
          offers: _lead.offers,
        );
        _isEditing = false;
      });
      widget.onStageChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prospect mis à jour'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> _deleteLead() async {
    if (_lead.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce prospect?'),
        content: Text(
            'Voulez-vous vraiment supprimer ${_lead.fullName}? Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await ApiService.instance.delete('/leads/${_lead.id}');
      widget.onStageChanged();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final stageColor = _getStageColor(_lead.stage);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du prospect'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _isLoading ? null : _saveEdits,
              icon: const Icon(Icons.check),
              tooltip: 'Sauvegarder',
            )
          else
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteLead();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // -- Header card --
                  _buildHeaderCard(stageColor),

                  const SizedBox(height: 16),

                  // -- Stage progression buttons --
                  _buildStageButtons(stageColor),

                  const SizedBox(height: 24),

                  // -- Contact info --
                  _buildSectionTitle('Contact'),
                  const SizedBox(height: 8),
                  _buildContactCard(),

                  const SizedBox(height: 24),

                  // -- Details --
                  _buildSectionTitle('Détails'),
                  const SizedBox(height: 8),
                  _buildDetailsCard(),

                  // -- Offers --
                  if (_lead.offers.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('Offres'),
                    const SizedBox(height: 8),
                    _buildOffersCard(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(Color stageColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: stageColor.withValues(alpha: 0.1),
            child: Text(
              _lead.fullName.isNotEmpty
                  ? _lead.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: stageColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _lead.fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stageColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _lead.stage.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: stageColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageButtons(Color stageColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avancer dans le pipeline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          // Stage progress dots
          _buildStageProgress(),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_prevStage != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _moveToStage(_prevStage!),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('← ${_prevStage!.label}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_prevStage != null) const SizedBox(width: 12),
              if (_nextStage != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _moveToStage(_nextStage!),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text('${_nextStage!.label} →'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: stageColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text(
                      '✓ Pipeline terminé',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStageProgress() {
    const stages = LeadStage.values;
    final currentIdx = stages.indexOf(_lead.stage);

    return Row(
      children: List.generate(stages.length, (i) {
        final isActive = i == currentIdx;
        final isPast = i < currentIdx;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isPast
                      ? const Color(0xFF10B981)
                      : isActive
                          ? _getStageColor(stages[i])
                          : const Color(0xFFE2E8F0),
                  border: isActive
                      ? Border.all(
                          color: _getStageColor(stages[i]),
                          width: 2,
                        )
                      : null,
                ),
              ),
              if (i < stages.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isPast
                        ? const Color(0xFF10B981)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _contactRow(Icons.email_outlined, 'Email', _lead.email,
              controller: _emailController),
          const Divider(height: 24),
          _contactRow(Icons.phone_outlined, 'Téléphone', _lead.phone,
              controller: _phoneController),
          if (_lead.source.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.source_outlined, 'Source', _lead.source),
          ],
          if (_lead.lastContact.isNotEmpty) ...[
            const Divider(height: 24),
            _infoRow(Icons.schedule_outlined, 'Dernier contact', _lead.lastContact),
          ],
          if (_lead.createdAt != null) ...[
            const Divider(height: 24),
            _infoRow(Icons.calendar_today_outlined, 'Créé le',
                DateFormat('dd MMM yyyy', 'fr').format(_lead.createdAt!)),
          ],
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value,
      {TextEditingController? controller}) {
    if (_isEditing && controller != null) {
      return Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
        ],
      );
    }
    return _infoRow(icon, label, value);
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget
          Row(
            children: [
              const Icon(Icons.attach_money_outlined,
                  size: 20, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Budget',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    if (_isEditing)
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _budgetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Budget (\$)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      )
                    else
                      Text(
                        _lead.budget > 0 ? '${_lead.budget}\$' : 'Non spécifié',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Desired unit
          Row(
            children: [
              const Icon(Icons.apartment_outlined,
                  size: 20, color: Color(0xFF64748B)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Type recherché',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 2),
                    if (_isEditing)
                      TextField(
                        controller: _desiredUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Type d\'unité',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      )
                    else
                      Text(
                        _lead.desiredUnit.isNotEmpty
                            ? _lead.desiredUnit
                            : 'Non spécifié',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Tags
          if (_lead.tags.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.label_outlined,
                    size: 20, color: Color(0xFF64748B)),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _lead.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E7FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4338CA),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],

          // Notes
          const Divider(height: 24),
          const Row(
            children: [
              Icon(Icons.notes_outlined,
                  size: 20, color: Color(0xFF64748B)),
              SizedBox(width: 12),
              Text('Notes',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 8),
          if (_isEditing)
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ajouter des notes...',
              ),
            )
          else
            Text(
              _lead.notes.isNotEmpty ? _lead.notes : 'Aucune note',
              style: TextStyle(
                fontSize: 14,
                color: _lead.notes.isNotEmpty
                    ? const Color(0xFF475569)
                    : const Color(0xFF94A3B8),
                fontStyle:
                    _lead.notes.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOffersCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _lead.offers.map((offer) {
          final statusColor = offer.status == 'accepted'
              ? const Color(0xFF10B981)
              : offer.status == 'rejected'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFFF59E0B);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offer.amount}\$',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        offer.sentAt.isNotEmpty ? offer.sentAt : 'Date inconnue',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _offerStatusLabel(offer.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.nouveau:
        return const Color(0xFF6B7280);
      case LeadStage.contacte:
        return const Color(0xFF3B82F6);
      case LeadStage.qualifie:
        return const Color(0xFF10B981);
      case LeadStage.visitePlanifiee:
        return const Color(0xFF8B5CF6);
      case LeadStage.offreEnvoyee:
        return const Color(0xFFF59E0B);
      case LeadStage.negociation:
        return const Color(0xFFEF4444);
      case LeadStage.bailSigne:
        return const Color(0xFF10B981);
    }
  }

  String _offerStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Acceptée';
      case 'rejected':
        return 'Refusée';
      case 'pending':
        return 'En attente';
      case 'sent':
        return 'Envoyée';
      default:
        return status;
    }
  }
}
