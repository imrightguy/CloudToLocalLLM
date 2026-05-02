import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';
import '../theme/app_spacing.dart';
import 'visit_form_screen.dart';

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
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
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
            backgroundColor: AppColors.error,
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
      appBar: ImmoAppBar(title: 'Détails du prospect', actions: [
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
                    Icon(Icons.delete_outline, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Supprimer',
                        style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ]),
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

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => VisitFormScreen(
                                    initialLeadId: _lead.id,
                                    initialDate: DateTime.now().add(const Duration(hours: 1)),
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Planifier une visite'),
                    ),
                  ),

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
            backgroundColor: stageColor.withValues(alpha: 0.1),
            child: Text(
              _lead.fullName.isNotEmpty ? _lead.fullName[0].toUpperCase() : '?',
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
                    color: AppColors.textPrimary,
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
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avancer dans le pipeline',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
                    onPressed:
                        _isLoading ? null : () => _moveToStage(_prevStage!),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text('← ${_prevStage!.label}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (_prevStage != null) const SizedBox(width: 12),
              if (_nextStage != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _isLoading ? null : () => _moveToStage(_nextStage!),
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
                        color: AppColors.success,
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
                      ? AppColors.success
                      : isActive
                          ? _getStageColor(stages[i])
                          : AppColors.border,
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
                        ? AppColors.success
                        : AppColors.border,
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
      decoration: AppSpacing.cardDecoration(),
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
            _infoRow(
                Icons.schedule_outlined, 'Dernier contact', _lead.lastContact),
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
          Icon(icon, size: 20, color: AppColors.textSecondary),
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
                value.isNotEmpty ? value : '—',
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

  Widget _buildDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Budget
          Row(
            children: [
              const Icon(Icons.attach_money_outlined,
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Budget',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                          color: AppColors.textPrimary,
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
                  size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Type recherché',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                          color: AppColors.textPrimary,
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
                    size: 20, color: AppColors.textSecondary),
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
                          color: AppColors.indigoTint,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.indigoDark,
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
              Icon(Icons.notes_outlined, size: 20, color: AppColors.textSecondary),
              SizedBox(width: 12),
              Text('Notes',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                    ? AppColors.label
                    : AppColors.textMuted,
                fontStyle: _lead.notes.isNotEmpty
                    ? FontStyle.normal
                    : FontStyle.italic,
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
      decoration: AppSpacing.cardDecoration(),
      child: Column(
        children: _lead.offers.map((offer) {
          final statusColor = offer.status == 'accepted'
              ? AppColors.success
              : offer.status == 'rejected'
                  ? AppColors.error
                  : AppColors.warning;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
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
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        offer.sentAt.isNotEmpty
                            ? offer.sentAt
                            : 'Date inconnue',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
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
        color: AppColors.textPrimary,
      ),
    );
  }

  Color _getStageColor(LeadStage stage) {
    switch (stage) {
      case LeadStage.nouveau:
        return AppColors.stageNouveau;
      case LeadStage.contacte:
        return AppColors.stageContacte;
      case LeadStage.qualifie:
        return AppColors.stageQualifie;
      case LeadStage.visitePlanifiee:
        return AppColors.stageVisitePlanifiee;
      case LeadStage.offreEnvoyee:
        return AppColors.stageOffreEnvoyee;
      case LeadStage.negociation:
        return AppColors.stageNegociation;
      case LeadStage.bailSigne:
        return AppColors.stageBailSigne;
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
