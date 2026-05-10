import 'package:flutter/material.dart';

import '../app_config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';

class DossierAssistantScreen extends StatefulWidget {
  const DossierAssistantScreen({super.key});

  @override
  State<DossierAssistantScreen> createState() => _DossierAssistantScreenState();
}

class _DossierAssistantScreenState extends State<DossierAssistantScreen> {
  static const String _companyId = AppConfig.demoCompanyId;

  final TextEditingController _reviewNotesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  List<LeadItem> _leads = [];
  List<UnitItem> _units = [];
  Map<String, dynamic>? _dossier;
  String? _selectedLeadId;
  String? _selectedUnitId;
  String _selectedCategory = 'maintenance';
  String _reviewStatus = 'approved';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _reviewNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.instance.get('/leads?limit=200'),
        ApiService.instance.get('/buildings/units'),
      ]);
      final leadRows = (results[0]['data'] as List<dynamic>? ?? const [])
          .map((row) => LeadItem.fromJson(row as Map<String, dynamic>))
          .toList();
      final unitRows = (results[1]['data'] as List<dynamic>? ?? const [])
          .map((row) => UnitItem.fromJson(row as Map<String, dynamic>))
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _leads = leadRows;
        _units = unitRows;
        _selectedLeadId ??= leadRows.isNotEmpty ? leadRows.first.id : null;
        _selectedUnitId ??= unitRows.isNotEmpty ? unitRows.first.id : null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createDossier() async {
    if (_selectedLeadId == null && _selectedUnitId == null) {
      setState(() {
        _errorMessage = 'Sélectionne au moins un locataire ou une unité.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.instance.post(
        '/companies/$_companyId/dossiers',
        {
          if (_selectedLeadId != null) 'leadId': _selectedLeadId,
          if (_selectedUnitId != null) 'unitId': _selectedUnitId,
          'problemCategory': _selectedCategory,
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dossier = (result['data'] as Map<String, dynamic>?) ?? {};
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _reviewDossier() async {
    final dossierId = _dossier?['id'] as String?;
    if (dossierId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.instance.patch(
        '/companies/$_companyId/dossiers/$dossierId/review',
        {
          'status': _reviewStatus,
          'reviewNotes': _reviewNotesController.text.trim(),
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dossier = (result['data'] as Map<String, dynamic>?) ?? {};
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isSaving = false;
      });
    }
  }

  Future<void> _exportDossier() async {
    final dossierId = _dossier?['id'] as String?;
    if (dossierId == null) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.instance.get('/companies/$_companyId/dossiers/$dossierId/export');
      if (!mounted) {
        return;
      }
      setState(() {
        _dossier = (result['data'] as Map<String, dynamic>?) ?? {};
        _isSaving = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isSaving = false;
      });
    }
  }

  String _leadLabel(LeadItem lead) {
    return lead.fullName.isEmpty ? lead.id ?? 'Locataire' : lead.fullName;
  }

  String _unitLabel(UnitItem unit) {
    final parts = <String>[];
    if (unit.number.isNotEmpty) {
      parts.add(unit.number);
    }
    if (unit.tenantName?.isNotEmpty == true) {
      parts.add(unit.tenantName!);
    }
    return parts.isEmpty ? unit.id ?? 'Unité' : parts.join(' · ');
  }

  List<Map<String, dynamic>> _facts() {
    final items = _dossier?['items'];
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    final exportSections = _dossier?['exportSections'];
    final facts = exportSections is Map<String, dynamic> ? exportSections['facts'] : null;
    if (facts is List) {
      return facts.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  List<String> _nextSteps() {
    final steps = _dossier?['nextSteps'];
    if (steps is List) {
      return steps.map((step) => step.toString()).toList();
    }
    final exportSections = _dossier?['exportSections'];
    final exportSteps = exportSections is Map<String, dynamic> ? exportSections['nextSteps'] : null;
    if (exportSteps is List) {
      return exportSteps.map((step) => step.toString()).toList();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Assistant TAL',
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _loadOptions,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadOptions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(
                      errorMessage: _errorMessage,
                      dossier: _dossier,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _ErrorBanner(message: _errorMessage!),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    _buildSelectionCard(),
                    const SizedBox(height: AppSpacing.lg),
                    if (_dossier != null) ...[
                      _buildDossierCard(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildReviewCard(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélection du dossier',
              style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choisis un locataire, une unité et une catégorie de problème pour assembler le dossier factuel.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String?>(
              initialValue: _selectedLeadId,
              decoration: const InputDecoration(labelText: 'Locataire'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')), 
                ..._leads.map((lead) => DropdownMenuItem<String?>(
                      value: lead.id,
                      child: Text(_leadLabel(lead)),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedLeadId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _selectedUnitId,
              decoration: const InputDecoration(labelText: 'Unité'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('—')),
                ..._units.map((unit) => DropdownMenuItem<String?>(
                      value: unit.id,
                      child: Text(_unitLabel(unit)),
                    )),
              ],
              onChanged: (value) => setState(() => _selectedUnitId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(labelText: 'Catégorie du problème'),
              items: const [
                DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                DropdownMenuItem(value: 'payment', child: Text('Paiement')),
                DropdownMenuItem(value: 'visit', child: Text('Visite')),
                DropdownMenuItem(value: 'lease', child: Text('Bail')),
                DropdownMenuItem(value: 'documents', child: Text('Documents')),
                DropdownMenuItem(value: 'general', child: Text('Général')),
              ],
              onChanged: (value) => setState(() => _selectedCategory = value ?? 'maintenance'),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _createDossier,
                icon: const Icon(Icons.auto_awesome_outlined),
                label: Text(_dossier == null ? 'Générer le dossier' : 'Rafraîchir le dossier'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDossierCard() {
    final dossier = _dossier ?? const {};
    final facts = _facts();
    final nextSteps = _nextSteps();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dossier factuel',
              style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              dossier['factualSummary']?.toString() ?? '',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusChip(label: dossier['status']?.toString() ?? 'draft', color: AppColors.primary),
                _StatusChip(label: dossier['problemCategory']?.toString() ?? '—', color: AppColors.info),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Faits', style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            ...facts.map(
              (fact) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.fact_check_outlined, color: AppColors.primary),
                  title: Text(fact['title']?.toString() ?? 'Fait'),
                  subtitle: Text(fact['summary']?.toString() ?? ''),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Étapes suivantes', style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            ...nextSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _exportDossier,
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exporter le dossier'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revue du gestionnaire',
              style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _reviewStatus,
              decoration: const InputDecoration(labelText: 'État de revue'),
              items: const [
                DropdownMenuItem(value: 'in_review', child: Text('En revue')),
                DropdownMenuItem(value: 'approved', child: Text('Approuvé')),
                DropdownMenuItem(value: 'exported', child: Text('Exporté')),
                DropdownMenuItem(value: 'archived', child: Text('Archivé')),
              ],
              onChanged: (value) => setState(() => _reviewStatus = value ?? 'approved'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _reviewNotesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notes de revue',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _reviewDossier,
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('Marquer comme revu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.errorMessage, required this.dossier});

  final String? errorMessage;
  final Map<String, dynamic>? dossier;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assistant TAL',
              style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Assembler un dossier factuel à partir des pièces déjà présentes dans ImmoGestion.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            if (dossier != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Dossier actif: ${dossier!['id'] ?? '—'}',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                errorMessage!,
                style: AppTypography.caption.copyWith(color: AppColors.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.18)),
      ),
      child: Text(message, style: AppTypography.body.copyWith(color: AppColors.error)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.08),
      labelStyle: AppTypography.caption.copyWith(color: color),
    );
  }
}
