import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';

class RenovationOpsScreen extends StatefulWidget {
  const RenovationOpsScreen({super.key});

  @override
  State<RenovationOpsScreen> createState() => _RenovationOpsScreenState();
}

class _RenovationOpsScreenState extends State<RenovationOpsScreen> {
  static const List<_RenovationApartment> _apartments = [
    _RenovationApartment(
      id: 'A-304',
      unitLabel: '304',
      buildingName: 'Place Du Parc',
      phase: _RenovationPhase.active,
      readiness: '71 % prêt',
      taskCount: 8,
      doneCount: 5,
      blockerCount: 1,
      nextStep: 'Peinture finale et inspection cuisine',
      updatedAt: 'Aujourd’hui • 14 h 20',
      blockerNote: 'Attente d’un luminaire pour le salon',
      tasks: [
        _RenovationTask(title: 'Retirer les anciens luminaires', status: _TaskStatus.done),
        _RenovationTask(title: 'Reboucher les trous', status: _TaskStatus.done),
        _RenovationTask(title: 'Peinture des murs', status: _TaskStatus.inProgress),
        _RenovationTask(title: 'Installer les fixtures finales', status: _TaskStatus.blocked),
      ],
    ),
    _RenovationApartment(
      id: 'B-212',
      unitLabel: '212',
      buildingName: 'Le Cardinal',
      phase: _RenovationPhase.blocked,
      readiness: '43 % prêt',
      taskCount: 6,
      doneCount: 2,
      blockerCount: 2,
      nextStep: 'Réception partielle après la livraison',
      updatedAt: 'Aujourd’hui • 09 h 05',
      blockerNote: 'Tuiles de salle de bain et hotte manquantes',
      tasks: [
        _RenovationTask(title: 'Démo salle de bain', status: _TaskStatus.done),
        _RenovationTask(title: 'Commander les tuiles', status: _TaskStatus.blocked),
        _RenovationTask(title: 'Installer la hotte', status: _TaskStatus.todo),
      ],
    ),
    _RenovationApartment(
      id: 'C-118',
      unitLabel: '118',
      buildingName: 'Ateliers Nord',
      phase: _RenovationPhase.ready,
      readiness: 'Prêt pour Leasing',
      taskCount: 4,
      doneCount: 4,
      blockerCount: 0,
      nextStep: 'Transmettre le statut de readiness au module Leasing',
      updatedAt: 'Hier • 18 h 40',
      blockerNote: '',
      tasks: [
        _RenovationTask(title: 'Nettoyage final', status: _TaskStatus.done),
        _RenovationTask(title: 'Photos de clôture', status: _TaskStatus.done),
        _RenovationTask(title: 'Validation readiness', status: _TaskStatus.done),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Rénovation Ops'),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModuleBoundaryCard(
                onOpenLeasingBridge: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leasing ne consomme que le statut de readiness.'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: const [
                  _SummaryCard(
                    label: 'Appartements actifs',
                    value: '2',
                    icon: Icons.construction_outlined,
                    accentColor: AppColors.primary,
                  ),
                  _SummaryCard(
                    label: 'Bloqueurs ouverts',
                    value: '3',
                    icon: Icons.warning_amber_rounded,
                    accentColor: AppColors.warning,
                  ),
                  _SummaryCard(
                    label: 'Tâches terminées',
                    value: '11',
                    icon: Icons.task_alt_rounded,
                    accentColor: AppColors.success,
                  ),
                  _SummaryCard(
                    label: 'Prêts pour Leasing',
                    value: '1',
                    icon: Icons.verified_rounded,
                    accentColor: AppColors.info,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Appartements en rénovation',
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Chaque carte donne le détail du logement, des tâches, des bloqueurs et du prochain jalon avant la remise au module Leasing.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              ..._apartments.map(
                (apartment) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _ApartmentCard(
                    apartment: apartment,
                    onTap: () => _openApartmentDetail(context, apartment),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Flux de travail',
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const _WorkflowLane(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Hooks prévus',
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _HookPanel(),
            ],
          ),
        ),
      ),
    );
  }

  void _openApartmentDetail(BuildContext context, _RenovationApartment apartment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ApartmentDetailSheet(apartment: apartment);
      },
    );
  }
}

class _ModuleBoundaryCard extends StatelessWidget {
  const _ModuleBoundaryCard({required this.onOpenLeasingBridge});

  final VoidCallback onOpenLeasingBridge;

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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: const Icon(
                    Icons.apartment_outlined,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Module séparé du Leasing',
                        style: AppTypography.sectionHeader.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rénovation Ops pilote la préparation physique des logements. Leasing ne lit que le statut de readiness, jamais les tâches ou les bloqueurs détaillés.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _BoundaryChip(
                  icon: Icons.task_alt_rounded,
                  label: 'Tâches par logement',
                ),
                _BoundaryChip(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photos terrain',
                ),
                _BoundaryChip(
                  icon: Icons.inventory_2_outlined,
                  label: 'Ordres et réception',
                ),
                _BoundaryChip(
                  icon: Icons.verified_outlined,
                  label: 'Readiness seulement vers Leasing',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onOpenLeasingBridge,
              icon: const Icon(Icons.call_made_rounded),
              label: const Text('Voir la passerelle de readiness'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(height: AppSpacing.sm),
              Text(
                value,
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApartmentCard extends StatelessWidget {
  const _ApartmentCard({required this.apartment, required this.onTap});

  final _RenovationApartment apartment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: apartment.phase.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Icon(
                      apartment.phase.icon,
                      color: apartment.phase.color,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logement ${apartment.unitLabel}',
                          style: AppTypography.bodyBold.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          apartment.buildingName,
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _StatusChip(
                              label: apartment.phase.label,
                              color: apartment.phase.color,
                            ),
                            _StatusChip(
                              label: apartment.readiness,
                              color: AppColors.info,
                            ),
                            _StatusChip(
                              label: '${apartment.blockerCount} bloqueur(s)',
                              color: apartment.blockerCount == 0
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              LinearProgressIndicator(
                value: apartment.doneCount / apartment.taskCount,
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(apartment.phase.color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '${apartment.doneCount}/${apartment.taskCount} tâches',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    apartment.updatedAt,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                apartment.nextStep,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowLane extends StatelessWidget {
  const _WorkflowLane();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: const [
            _WorkflowStep(
              label: 'Intake',
              subtitle: 'Photos, notes et matériel manquant',
              icon: Icons.inbox_outlined,
              color: AppColors.info,
            ),
            _WorkflowStep(
              label: 'En cours',
              subtitle: 'Tâches actives et suivi terrain',
              icon: Icons.construction_outlined,
              color: AppColors.primary,
            ),
            _WorkflowStep(
              label: 'Bloqué',
              subtitle: 'Ordre, réception ou décision manquante',
              icon: Icons.block_outlined,
              color: AppColors.warning,
            ),
            _WorkflowStep(
              label: 'Prêt pour Leasing',
              subtitle: 'Readiness transmis, détail caché',
              icon: Icons.verified_rounded,
              color: AppColors.success,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStep extends StatelessWidget {
  const _WorkflowStep({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.16)),
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
                    style: AppTypography.bodyBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HookPanel extends StatelessWidget {
  const _HookPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _HookRow(
              icon: Icons.inventory_2_outlined,
              title: 'Ordres et réception',
              subtitle: 'Connecter les commandes aux tâches et au logement.',
            ),
            SizedBox(height: AppSpacing.md),
            _HookRow(
              icon: Icons.photo_camera_outlined,
              title: 'Intake photo / SMS',
              subtitle: 'Récupérer les photos et les updates terrain sans flow lourd.',
            ),
            SizedBox(height: AppSpacing.md),
            _HookRow(
              icon: Icons.report_problem_outlined,
              title: 'Bloqueurs',
              subtitle: 'Mettre en évidence les matériaux manquants et les décisions requises.',
            ),
          ],
        ),
      ),
    );
  }
}

class _HookRow extends StatelessWidget {
  const _HookRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApartmentDetailSheet extends StatelessWidget {
  const _ApartmentDetailSheet({required this.apartment});

  final _RenovationApartment apartment;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Détail du logement ${apartment.unitLabel}',
                  style: AppTypography.sectionHeader.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  apartment.buildingName,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _StatusChip(label: apartment.phase.label, color: apartment.phase.color),
                    _StatusChip(label: apartment.readiness, color: AppColors.info),
                    _StatusChip(
                      label: '${apartment.doneCount}/${apartment.taskCount} tâches',
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Tâches',
                  style: AppTypography.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...apartment.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _TaskTile(task: task),
                  ),
                ),
                if (apartment.blockerNote.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Bloqueur principal',
                    style: AppTypography.bodyBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      apartment.blockerNote,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Prochain jalon',
                  style: AppTypography.bodyBold.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  apartment.nextStep,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text('Ajouter une tâche'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Voir les photos'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Marquer prêt'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final _RenovationTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Icon(task.status.icon, color: task.status.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              task.title,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            task.status.label,
            style: AppTypography.caption.copyWith(
              color: task.status.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryChip extends StatelessWidget {
  const _BoundaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      backgroundColor: AppColors.primarySurface,
      side: BorderSide.none,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

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

enum _RenovationPhase {
  active('En cours', AppColors.primary, Icons.construction_outlined),
  blocked('Bloqué', AppColors.warning, Icons.block_outlined),
  ready('Prêt', AppColors.success, Icons.verified_rounded);

  const _RenovationPhase(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

enum _TaskStatus {
  todo('À faire', AppColors.textSecondary, Icons.radio_button_unchecked_rounded),
  inProgress('En cours', AppColors.primary, Icons.timelapse_rounded),
  blocked('Bloqué', AppColors.warning, Icons.warning_amber_rounded),
  done('Terminé', AppColors.success, Icons.check_circle_rounded);

  const _TaskStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class _RenovationApartment {
  const _RenovationApartment({
    required this.id,
    required this.unitLabel,
    required this.buildingName,
    required this.phase,
    required this.readiness,
    required this.taskCount,
    required this.doneCount,
    required this.blockerCount,
    required this.nextStep,
    required this.updatedAt,
    required this.blockerNote,
    required this.tasks,
  });

  final String id;
  final String unitLabel;
  final String buildingName;
  final _RenovationPhase phase;
  final String readiness;
  final int taskCount;
  final int doneCount;
  final int blockerCount;
  final String nextStep;
  final String updatedAt;
  final String blockerNote;
  final List<_RenovationTask> tasks;
}

class _RenovationTask {
  const _RenovationTask({required this.title, required this.status});

  final String title;
  final _TaskStatus status;
}
