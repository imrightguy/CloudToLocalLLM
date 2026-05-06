import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';

class DailyTaskTrackerScreen extends StatefulWidget {
  const DailyTaskTrackerScreen({super.key});

  @override
  State<DailyTaskTrackerScreen> createState() => _DailyTaskTrackerScreenState();
}

class _DailyTaskTrackerScreenState extends State<DailyTaskTrackerScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  _TaskTrackerSnapshot _snapshot = _TaskTrackerSnapshot.empty();
  final TextEditingController _noteController = TextEditingController(
    text: 'Relancer le filtre HVAC du logement 3B et confirmer la visite avec le concierge.',
  );
  final List<_RecurringTemplate> _savedTemplates = [];
  final List<_ConvertedTaskPreview> _convertedTasks = [];
  String _selectedScope = 'building';
  String _selectedCadence = 'weekly';

  @override
  void initState() {
    super.initState();
    _fetchTracker();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _fetchTracker() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.instance.get('/renovations/dashboard');
      final data = response['data'] as Map<String, dynamic>;
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _TaskTrackerSnapshot.fromJson(data);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = _TaskTrackerSnapshot.empty();
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<_TaskTrackerItem> get _sortedItems {
    final items = _snapshot.workItems.toList();
    items.sort((left, right) {
      final leftRank = left.priorityRank;
      final rightRank = right.priorityRank;
      if (leftRank != rightRank) {
        return leftRank.compareTo(rightRank);
      }
      final leftDue = left.nextDueAt?.millisecondsSinceEpoch ?? 0;
      final rightDue = right.nextDueAt?.millisecondsSinceEpoch ?? 0;
      if (leftDue != rightDue) {
        if (leftDue == 0) {
          return 1;
        }
        if (rightDue == 0) {
          return -1;
        }
        return leftDue.compareTo(rightDue);
      }
      return left.buildingName.compareTo(right.buildingName);
    });
    return items;
  }

  List<_TaskTrackerItem> get _todayQueue {
    final items = <_TaskTrackerItem>[];
    for (final item in _sortedItems) {
      if (item.priorityRank <= 2 || item.isBlocked) {
        items.add(item);
      }
    }
    return items.isEmpty ? _sortedItems.take(5).toList() : items;
  }

  List<_RecurringTemplate> get _recurringSuggestions {
    final templates = <_RecurringTemplate>[];
    for (final building in _snapshot.buildings.take(4)) {
      templates.add(
        _RecurringTemplate(
          title: 'Entretien ${building.buildingName}',
          scopeLabel: 'Immeuble',
          cadenceLabel: building.overdueTaskCount > 0
              ? 'Hebdomadaire'
              : building.dueSoonTaskCount > 0
                  ? 'Aux 2 semaines'
                  : 'Mensuelle',
          summary: '${building.apartmentCount} logements · ${building.overdueTaskCount} en retard',
          rationale: building.overdueTaskCount > 0
              ? 'Cadence resserrée pour réduire les retards existants.'
              : 'Cadence plus légère tant que les échéances restent stables.',
        ),
      );
    }

    for (final item in _todayQueue.take(3)) {
      templates.add(
        _RecurringTemplate(
          title: 'Suivi ${item.unitLabel}',
          scopeLabel: 'Unité',
          cadenceLabel: item.dueSoonTaskCount > 0 ? 'Hebdomadaire' : 'Mensuelle',
          summary: item.buildingName,
          rationale: item.priorityReason,
        ),
      );
    }

    return templates;
  }

  void _saveRecurringTemplate() {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      return;
    }

    setState(() {
      _savedTemplates.insert(
        0,
        _RecurringTemplate(
          title: _buildTemplateTitle(note),
          scopeLabel: _selectedScope == 'building' ? 'Immeuble' : _selectedScope == 'unit' ? 'Unité' : 'Zone commune',
          cadenceLabel: _selectedCadence == 'weekly'
              ? 'Hebdomadaire'
              : _selectedCadence == 'monthly'
                  ? 'Mensuelle'
                  : 'Trimestrielle',
          summary: _noteScopeSummary(note),
          rationale: 'Gabarit enregistré depuis une note opérationnelle.',
        ),
      );
    });
  }

  void _convertNoteToTask() {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      return;
    }

    setState(() {
      _convertedTasks.insert(
        0,
        _ConvertedTaskPreview.fromNote(
          note: note,
          scopePreference: _selectedScope,
          cadencePreference: _selectedCadence,
        ),
      );
    });
  }

  String _buildTemplateTitle(String note) {
    final compact = note.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 60) {
      return compact;
    }
    return '${compact.substring(0, 57)}...';
  }

  String _noteScopeSummary(String note) {
    final lower = note.toLowerCase();
    final buildingHint = lower.contains('immeuble') || lower.contains('bâtiment') || lower.contains('building');
    final unitHint = RegExp(r'\b\d+[a-z]?\b', caseSensitive: false).hasMatch(note) || lower.contains('logement');
    if (buildingHint && unitHint) {
      return 'Portée mixte bâtiment + unité';
    }
    if (buildingHint) {
      return 'Portée bâtiment';
    }
    if (unitHint) {
      return 'Portée unité';
    }
    return 'Portée à confirmer';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(
        title: 'Tâches du jour',
        actions: [
          IconButton(
            tooltip: 'Rafraîchir',
            onPressed: _fetchTracker,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchTracker,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderCard(
                      summary: _snapshot.summary,
                      asOfLabel: _snapshot.asOf != null
                          ? 'Mis à jour ${DateFormat('d MMM HH:mm', 'fr').format(_snapshot.asOf!.toLocal())}'
                          : 'Vue de travail',
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _InlineNotice(
                        icon: Icons.warning_amber_rounded,
                        label: 'Source dégradée',
                        message: _errorMessage!,
                        color: AppColors.warning,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(
                      title: 'Travail du jour',
                      subtitle: 'Les cartes ci-dessous sont triées par urgence, retard et fenêtre d’échéance.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 1100
                            ? (constraints.maxWidth - AppSpacing.md) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: _todayQueue.map((item) {
                            return SizedBox(
                              width: cardWidth,
                              child: _TaskCard(item: item),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(
                      title: 'Scénarios récurrents',
                      subtitle: 'Des gabarits de bâtiment et d’unité que l’équipe peut reprendre pour planifier des cycles réguliers.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 1100
                            ? (constraints.maxWidth - AppSpacing.md) / 2
                            : constraints.maxWidth;
                        final templates = [..._recurringSuggestions, ..._savedTemplates];
                        return Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: templates.map((template) {
                            return SizedBox(
                              width: cardWidth,
                              child: _RecurringTemplateCard(template: template),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(
                      title: 'Conversion note → tâche',
                      subtitle: 'Prototype de saisie rapide pour transformer une note terrain en tâche ou en gabarit récurrent.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _NoteConversionComposer(
                      controller: _noteController,
                      selectedScope: _selectedScope,
                      selectedCadence: _selectedCadence,
                      onScopeChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedScope = value;
                        });
                      },
                      onCadenceChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _selectedCadence = value;
                        });
                      },
                      onConvertToTask: _convertNoteToTask,
                      onSaveRecurringTemplate: _saveRecurringTemplate,
                    ),
                    if (_convertedTasks.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      ..._convertedTasks.map(
                        (preview) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: _ConvertedTaskCard(preview: preview),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    const _SectionHeader(
                      title: 'Pourquoi cette priorité ?',
                      subtitle: 'La priorisation est visible, pas magique: elle s’appuie sur le statut, l’échéance et l’âge du dossier.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PriorityExplanationCard(item: _sortedItems.isNotEmpty ? _sortedItems.first : null),
                  ],
                ),
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.summary, required this.asOfLabel});

  final _TaskTrackerSummary summary;
  final String asOfLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vue quotidienne des tâches',
                        style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Les tâches du jour, les retards et les cycles récurrents sont regroupés dans une seule surface de décision.',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _StatusPill(label: asOfLabel, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusPill(label: '${summary.overdueTasks} en retard', color: AppColors.error),
                _StatusPill(label: '${summary.dueSoonTasks} à faire cette semaine', color: AppColors.warning),
                _StatusPill(label: '${summary.activeApartments} dossiers actifs', color: AppColors.info),
                _StatusPill(label: '${summary.readyApartments} prêts', color: AppColors.success),
                _StatusPill(label: '${summary.properties} immeubles', color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.item});

  final _TaskTrackerItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logement ${item.unitLabel}',
                        style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.buildingName,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: item.phaseLabel, color: item.phaseColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              item.readiness,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusPill(label: '${item.doneCount}/${item.taskCount} tâches', color: AppColors.success),
                _StatusPill(label: item.dueDateLabel.isNotEmpty ? item.dueDateLabel : 'Sans échéance', color: item.dueColor),
                if (item.assignedEmployeeLabel.isNotEmpty)
                  _StatusPill(label: item.assignedEmployeeLabel, color: AppColors.info),
                _StatusPill(label: item.ageLabel, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _InlineNotice(
              icon: Icons.tips_and_updates_outlined,
              label: 'Pourquoi maintenant?',
              message: item.priorityReason,
              color: item.priorityColor,
            ),
            if (item.reasonChips.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: item.reasonChips
                    .map(
                      (chip) => _StatusPill(
                        label: chip,
                        color: item.priorityColor,
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Prochain jalon',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              item.nextStep,
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTemplateCard extends StatelessWidget {
  const _RecurringTemplateCard({required this.template});

  final _RecurringTemplate template;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    template.title,
                    style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                _StatusPill(label: template.cadenceLabel, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusPill(label: template.scopeLabel, color: AppColors.info),
                _StatusPill(label: template.summary, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              template.rationale,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteConversionComposer extends StatelessWidget {
  const _NoteConversionComposer({
    required this.controller,
    required this.selectedScope,
    required this.selectedCadence,
    required this.onScopeChanged,
    required this.onCadenceChanged,
    required this.onConvertToTask,
    required this.onSaveRecurringTemplate,
  });

  final TextEditingController controller;
  final String selectedScope;
  final String selectedCadence;
  final ValueChanged<String?> onScopeChanged;
  final ValueChanged<String?> onCadenceChanged;
  final VoidCallback onConvertToTask;
  final VoidCallback onSaveRecurringTemplate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note terrain',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                ChoiceChip(
                  label: const Text('Immeuble'),
                  selected: selectedScope == 'building',
                  onSelected: (_) => onScopeChanged('building'),
                ),
                ChoiceChip(
                  label: const Text('Unité'),
                  selected: selectedScope == 'unit',
                  onSelected: (_) => onScopeChanged('unit'),
                ),
                ChoiceChip(
                  label: const Text('Zone commune'),
                  selected: selectedScope == 'common_area',
                  onSelected: (_) => onScopeChanged('common_area'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                ChoiceChip(
                  label: const Text('Hebdomadaire'),
                  selected: selectedCadence == 'weekly',
                  onSelected: (_) => onCadenceChanged('weekly'),
                ),
                ChoiceChip(
                  label: const Text('Mensuelle'),
                  selected: selectedCadence == 'monthly',
                  onSelected: (_) => onCadenceChanged('monthly'),
                ),
                ChoiceChip(
                  label: const Text('Trimestrielle'),
                  selected: selectedCadence == 'quarterly',
                  onSelected: (_) => onCadenceChanged('quarterly'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: onSaveRecurringTemplate,
                  icon: const Icon(Icons.repeat_rounded),
                  label: const Text('Enregistrer comme gabarit'),
                ),
                ElevatedButton.icon(
                  onPressed: onConvertToTask,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: const Text('Convertir en tâche'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConvertedTaskCard extends StatelessWidget {
  const _ConvertedTaskCard({required this.preview});

  final _ConvertedTaskPreview preview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    preview.generatedTitle,
                    style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                ),
                _StatusPill(label: preview.confidenceLabel, color: preview.confidenceColor),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _StatusPill(label: preview.scopeLabel, color: AppColors.info),
                _StatusPill(label: preview.cadenceLabel, color: AppColors.primary),
                _StatusPill(label: preview.dueLabel, color: AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              preview.sourceNote,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityExplanationCard extends StatelessWidget {
  const _PriorityExplanationCard({required this.item});

  final _TaskTrackerItem? item;

  @override
  Widget build(BuildContext context) {
    final explanation = item;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Règles de tri visibles',
              style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '1. Les dossiers bloqués passent en premier. 2. Les tâches en retard ou dues aujourd’hui suivent. 3. Les tâches de la semaine viennent ensuite. 4. Les dossiers stables et prêts restent visibles, mais plus bas.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            if (explanation != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InlineNotice(
                icon: Icons.priority_high_rounded,
                label: 'Tête de file actuelle',
                message: explanation.priorityReason,
                color: explanation.priorityColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.label,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTypography.body.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TaskTrackerSnapshot {
  const _TaskTrackerSnapshot({
    required this.summary,
    required this.workItems,
    required this.buildings,
    required this.asOf,
  });

  factory _TaskTrackerSnapshot.fromJson(Map<String, dynamic> json) {
    final workItems = ((json['apartments'] as List<dynamic>?) ?? const [])
        .map((entry) => _TaskTrackerItem.fromJson(entry as Map<String, dynamic>))
        .toList();
    final buildings = ((json['byBuilding'] as List<dynamic>?) ?? const [])
        .map((entry) => _TrackerBuildingSummary.fromJson(entry as Map<String, dynamic>))
        .toList();
    return _TaskTrackerSnapshot(
      summary: _TaskTrackerSummary.fromJson((json['summary'] as Map<String, dynamic>?) ?? const {}),
      workItems: workItems,
      buildings: buildings,
      asOf: json['asOf'] != null ? DateTime.tryParse(json['asOf'] as String) : null,
    );
  }

  factory _TaskTrackerSnapshot.empty() {
    return const _TaskTrackerSnapshot(
      summary: _TaskTrackerSummary(),
      workItems: [],
      buildings: [],
      asOf: null,
    );
  }

  final _TaskTrackerSummary summary;
  final List<_TaskTrackerItem> workItems;
  final List<_TrackerBuildingSummary> buildings;
  final DateTime? asOf;
}

class _TaskTrackerSummary {
  const _TaskTrackerSummary({
    this.activeApartments = 0,
    this.readyApartments = 0,
    this.overdueTasks = 0,
    this.dueSoonTasks = 0,
    this.properties = 0,
  });

  factory _TaskTrackerSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num?)?.toInt() ?? 0;
    return _TaskTrackerSummary(
      activeApartments: toInt(json['activeApartments']),
      readyApartments: toInt(json['readyApartments']),
      overdueTasks: toInt(json['overdueTasks']),
      dueSoonTasks: toInt(json['dueSoonTasks']),
      properties: toInt(json['properties']),
    );
  }

  final int activeApartments;
  final int readyApartments;
  final int overdueTasks;
  final int dueSoonTasks;
  final int properties;
}

class _TrackerBuildingSummary {
  const _TrackerBuildingSummary({
    required this.buildingName,
    required this.apartmentCount,
    required this.overdueTaskCount,
    required this.dueSoonTaskCount,
  });

  factory _TrackerBuildingSummary.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) => (value as num?)?.toInt() ?? 0;
    return _TrackerBuildingSummary(
      buildingName: json['buildingName'] as String? ?? '—',
      apartmentCount: toInt(json['apartmentCount']),
      overdueTaskCount: toInt(json['overdueTaskCount']),
      dueSoonTaskCount: toInt(json['dueSoonTaskCount']),
    );
  }

  final String buildingName;
  final int apartmentCount;
  final int overdueTaskCount;
  final int dueSoonTaskCount;
}

class _TaskTrackerItem {
  const _TaskTrackerItem({
    required this.id,
    required this.unitLabel,
    required this.buildingName,
    required this.phase,
    required this.readiness,
    required this.taskCount,
    required this.doneCount,
    required this.overdueTaskCount,
    required this.dueSoonTaskCount,
    required this.nextStep,
    required this.updatedAt,
    required this.blockerNote,
    required this.tasks,
    this.nextDueAt,
    this.assignedEmployeeLabel = '',
    this.dueDateLabel = '',
  });

  factory _TaskTrackerItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final nextDueAt = parseDate(json['nextDueAt']);
    final updatedAt = parseDate(json['updatedAt']);
    final dueDateLabel = (json['dueDateLabel'] as String?) ?? _formatDueLabel(nextDueAt);

    return _TaskTrackerItem(
      id: json['id'] as String? ?? '',
      unitLabel: json['unitLabel'] as String? ?? '',
      buildingName: json['buildingName'] as String? ?? '',
      phase: json['phase'] as String? ?? 'active',
      readiness: json['readiness'] as String? ?? '',
      taskCount: (json['taskCount'] as num?)?.toInt() ?? 0,
      doneCount: (json['doneCount'] as num?)?.toInt() ?? 0,
      overdueTaskCount: (json['overdueTaskCount'] as num?)?.toInt() ?? 0,
      dueSoonTaskCount: (json['dueSoonTaskCount'] as num?)?.toInt() ?? 0,
      nextStep: json['nextStep'] as String? ?? '',
      updatedAt: updatedAt,
      blockerNote: json['blockerNote'] as String? ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((task) => _TaskStep.fromJson(task as Map<String, dynamic>))
              .toList() ??
          const [],
      nextDueAt: nextDueAt,
      assignedEmployeeLabel: json['assignedEmployeeLabel'] as String? ?? '',
      dueDateLabel: dueDateLabel,
    );
  }

  int get priorityRank {
    if (isBlocked) {
      return 0;
    }
    if (overdueTaskCount > 0) {
      return 1;
    }
    if (nextDueAt != null) {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final due = DateTime(nextDueAt!.year, nextDueAt!.month, nextDueAt!.day);
      if (due.isBefore(startOfToday)) {
        return 1;
      }
      if (due.difference(startOfToday).inDays <= 7) {
        return 2;
      }
      return 3;
    }
    if (phase == 'active') {
      return 4;
    }
    return 5;
  }

  bool get isReady => phase == 'ready';
  bool get isBlocked => phase == 'blocked' || blockerNote.isNotEmpty;
  Color get phaseColor {
    switch (phase) {
      case 'blocked':
        return AppColors.warning;
      case 'ready':
        return AppColors.success;
      case 'active':
      default:
        return AppColors.primary;
    }
  }

  String get phaseLabel {
    switch (phase) {
      case 'blocked':
        return 'Bloqué';
      case 'ready':
        return 'Prêt';
      case 'active':
      default:
        return 'En cours';
    }
  }

  Color get priorityColor {
    if (isBlocked || overdueTaskCount > 0) {
      return AppColors.error;
    }
    if (dueSoonTaskCount > 0 || nextDueAt != null) {
      return AppColors.warning;
    }
    if (isReady) {
      return AppColors.success;
    }
    return AppColors.info;
  }

  String get ageLabel {
    if (updatedAt == null) {
      return 'Âge inconnu';
    }
    final difference = DateTime.now().difference(updatedAt!.toLocal());
    if (difference.inDays > 0) {
      return 'Âge ${difference.inDays} j';
    }
    if (difference.inHours > 0) {
      return 'Âge ${difference.inHours} h';
    }
    if (difference.inMinutes > 0) {
      return 'Âge ${difference.inMinutes} min';
    }
    return 'À jour';
  }

  String get priorityReason {
    final reasons = <String>[];
    if (isBlocked) {
      reasons.add('Bloqué par une dépendance ou un point d’arrêt terrain.');
    }
    if (overdueTaskCount > 0) {
      reasons.add('$overdueTaskCount tâche(s) sont déjà en retard.');
    }
    if (dueDateLabel.isNotEmpty) {
      reasons.add('Échéance affichée: $dueDateLabel.');
    }
    if (dueSoonTaskCount > 0) {
      reasons.add('$dueSoonTaskCount tâche(s) tombent dans la fenêtre de la semaine.');
    }
    if (reasons.isEmpty) {
      reasons.add('Ordre conservé pour garder les dossiers actifs visibles sans masquer les urgences.');
    }
    return reasons.join(' ');
  }

  List<String> get reasonChips {
    final chips = <String>[];
    if (isBlocked) {
      chips.add('bloqué');
    }
    if (overdueTaskCount > 0) {
      chips.add('retard');
    }
    if (nextDueAt != null) {
      chips.add('échéance');
    }
    if (dueSoonTaskCount > 0) {
      chips.add('cette semaine');
    }
    if (updatedAt != null) {
      chips.add(ageLabel);
    }
    return chips;
  }

  Color get dueColor {
    if (nextDueAt == null) {
      return AppColors.textSecondary;
    }
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDueAt!.year, nextDueAt!.month, nextDueAt!.day);
    if (due.isBefore(startOfToday)) {
      return AppColors.error;
    }
    if (due.difference(startOfToday).inDays <= 7) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  final String id;
  final String unitLabel;
  final String buildingName;
  final String phase;
  final String readiness;
  final int taskCount;
  final int doneCount;
  final int overdueTaskCount;
  final int dueSoonTaskCount;
  final String nextStep;
  final DateTime? updatedAt;
  final String blockerNote;
  final List<_TaskStep> tasks;
  final DateTime? nextDueAt;
  final String assignedEmployeeLabel;
  final String dueDateLabel;
}

class _TaskStep {
  const _TaskStep({required this.title, required this.status});

  factory _TaskStep.fromJson(Map<String, dynamic> json) {
    return _TaskStep(
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  final String title;
  final String status;
}

class _RecurringTemplate {
  const _RecurringTemplate({
    required this.title,
    required this.scopeLabel,
    required this.cadenceLabel,
    required this.summary,
    required this.rationale,
  });

  final String title;
  final String scopeLabel;
  final String cadenceLabel;
  final String summary;
  final String rationale;
}

class _ConvertedTaskPreview {
  const _ConvertedTaskPreview({
    required this.sourceNote,
    required this.generatedTitle,
    required this.scopeLabel,
    required this.cadenceLabel,
    required this.dueLabel,
    required this.confidenceLabel,
    required this.confidenceColor,
  });

  factory _ConvertedTaskPreview.fromNote({
    required String note,
    required String scopePreference,
    required String cadencePreference,
  }) {
    final lower = note.toLowerCase();
    final hasBuildingHint = lower.contains('immeuble') || lower.contains('bâtiment') || lower.contains('building');
    final hasUnitHint = RegExp(r'\b\d+[a-z]?\b', caseSensitive: false).hasMatch(note) || lower.contains('logement');
    final dueLabel = lower.contains('aujourd')
        ? 'Aujourd’hui'
        : lower.contains('demain')
            ? 'Demain'
            : lower.contains('semaine')
                ? 'Cette semaine'
                : 'À planifier';
    final title = _shorten(note, 72);
    final scopeLabel = scopePreference == 'building'
        ? 'Immeuble'
        : scopePreference == 'unit'
            ? 'Unité'
            : 'Zone commune';
    final cadenceLabel = cadencePreference == 'weekly'
        ? 'Hebdomadaire'
        : cadencePreference == 'monthly'
            ? 'Mensuelle'
            : 'Trimestrielle';
    final confidence = hasBuildingHint && hasUnitHint
        ? ('Haute', AppColors.success)
        : hasBuildingHint || hasUnitHint
            ? ('Moyenne', AppColors.warning)
            : ('Faible', AppColors.textSecondary);

    return _ConvertedTaskPreview(
      sourceNote: note,
      generatedTitle: 'Tâche: $title',
      scopeLabel: scopeLabel,
      cadenceLabel: cadenceLabel,
      dueLabel: dueLabel,
      confidenceLabel: confidence.$1,
      confidenceColor: confidence.$2,
    );
  }

  final String sourceNote;
  final String generatedTitle;
  final String scopeLabel;
  final String cadenceLabel;
  final String dueLabel;
  final String confidenceLabel;
  final Color confidenceColor;
}

String _shorten(String value, int maxLength) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= maxLength) {
    return compact;
  }
  return '${compact.substring(0, maxLength - 3)}...';
}

String _formatDueLabel(DateTime? nextDueAt) {
  if (nextDueAt == null) {
    return '';
  }
  return 'Échéance ${DateFormat('dd/MM').format(nextDueAt.toLocal())}';
}
