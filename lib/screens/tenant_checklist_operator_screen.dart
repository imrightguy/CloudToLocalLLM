// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';

import '../services/tenant_checklist_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/immo_app_bar.dart';

class TenantChecklistOperatorScreen extends StatefulWidget {
  const TenantChecklistOperatorScreen({
    super.key,
    required this.unitId,
    required this.unitLabel,
    required this.buildingName,
    this.leaseId,
    this.tenantName,
    this.tenantPhone,
    this.checklistType = 'move_in',
  });

  final String unitId;
  final String unitLabel;
  final String buildingName;
  final String? leaseId;
  final String? tenantName;
  final String? tenantPhone;
  final String checklistType;

  @override
  State<TenantChecklistOperatorScreen> createState() => _TenantChecklistOperatorScreenState();
}

class _TenantChecklistOperatorScreenState extends State<TenantChecklistOperatorScreen> {
  final _tenantNameController = TextEditingController();
  final _tenantPhoneController = TextEditingController();
  final _confirmationNoteController = TextEditingController();
  final _pauseReasonController = TextEditingController();

  final Map<String, _ChecklistStepController> _stepControllers = {};

  bool _isCreating = false;
  bool _isRefreshing = false;
  bool _isPausing = false;
  bool _isResuming = false;
  bool _isSubmitting = false;
  String? _sessionId;
  String? _sessionState;
  String _checklistType = 'move_in';
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _steps = const [];
  String? _errorMessage;

  bool get _hasSession => _sessionId != null && _sessionId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _checklistType = widget.checklistType;
    _tenantNameController.text = widget.tenantName ?? '';
    _tenantPhoneController.text = widget.tenantPhone ?? '';
  }

  @override
  void dispose() {
    _tenantNameController.dispose();
    _tenantPhoneController.dispose();
    _confirmationNoteController.dispose();
    _pauseReasonController.dispose();
    for (final controller in _stepControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _createSession() async {
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final data = await TenantChecklistService.instance.startChecklist(
        unitId: widget.unitId,
        leaseId: widget.leaseId,
        checklistType: _checklistType,
        tenantName: _tenantNameController.text.trim(),
        tenantPhone: _tenantPhoneController.text.trim(),
        metadata: {
          'source': 'renovation_ops',
          'buildingName': widget.buildingName,
          'unitLabel': widget.unitLabel,
        },
      );
      _applyGraph(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist créée et prête à être complétée'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur à la création: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _refreshSummary({bool managerView = false}) async {
    if (!_hasSession) return;
    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final data = await TenantChecklistService.instance.fetchSummary(
        _sessionId!,
        managerView: managerView,
      );
      _applyGraph(data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de rafraîchissement: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _pauseSession() async {
    if (!_hasSession) return;
    setState(() {
      _isPausing = true;
      _errorMessage = null;
    });

    try {
      final data = await TenantChecklistService.instance.pauseChecklist(
        _sessionId!,
        reason: _pauseReasonController.text.trim(),
        metadata: {
          'source': 'renovation_ops',
          'buildingName': widget.buildingName,
          'unitLabel': widget.unitLabel,
        },
      );
      _applyGraph(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist mise en pause'),
          backgroundColor: AppColors.warning,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de pause: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPausing = false);
      }
    }
  }

  Future<void> _resumeSession() async {
    if (!_hasSession) return;
    setState(() {
      _isResuming = true;
      _errorMessage = null;
    });

    try {
      final data = await TenantChecklistService.instance.resumeChecklist(
        _sessionId!,
        metadata: {
          'source': 'renovation_ops',
          'buildingName': widget.buildingName,
          'unitLabel': widget.unitLabel,
        },
      );
      _applyGraph(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist reprise'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de reprise: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isResuming = false);
      }
    }
  }

  Future<void> _submitSession() async {
    if (!_hasSession) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final data = await TenantChecklistService.instance.submitChecklist(
        _sessionId!,
        confirmationNote: _confirmationNoteController.text.trim(),
        stepUpdates: _buildStepUpdates(),
        attachments: _buildAttachments(),
        signatures: _buildSignatures(),
        metadata: {
          'source': 'renovation_ops',
          'buildingName': widget.buildingName,
          'unitLabel': widget.unitLabel,
        },
      );
      _applyGraph(data);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist soumise avec succès'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de soumission: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _applyGraph(Map<String, dynamic> graph) {
    final session = graph['session'] as Map<String, dynamic>? ?? const {};
    final steps = (graph['steps'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final summary = graph['summary'] as Map<String, dynamic>?;
    setState(() {
      _summary = summary;
      _sessionId = session['id'] as String?;
      _sessionState = session['state'] as String?;
      _steps = steps;
      _syncStepControllers(steps);
    });
  }

  void _syncStepControllers(List<Map<String, dynamic>> steps) {
    final activeKeys = <String>{};

    for (final step in steps) {
      final stepKey = step['stepKey']?.toString() ?? '';
      if (stepKey.isEmpty) continue;
      activeKeys.add(stepKey);
      final controller = _stepControllers.putIfAbsent(
        stepKey,
        () => _ChecklistStepController(stepKey: stepKey),
      );
      controller.status = step['status']?.toString() ?? controller.status;
      final notes = step['notes']?.toString() ?? '';
      if (controller.notesController.text.isEmpty && notes.isNotEmpty) {
        controller.notesController.text = notes;
      }
      final blockedReason = step['blockedReason']?.toString() ?? '';
      if (controller.blockedReasonController.text.isEmpty && blockedReason.isNotEmpty) {
        controller.blockedReasonController.text = blockedReason;
      }
      final metadata = step['metadata'];
      if (controller.photoUrlController.text.isEmpty && metadata is Map<String, dynamic>) {
        final photoUrl = metadata['photoUrl']?.toString() ?? '';
        if (photoUrl.isNotEmpty) {
          controller.photoUrlController.text = photoUrl;
        }
      }
    }

    final removedKeys = _stepControllers.keys.where((key) => !activeKeys.contains(key)).toList();
    for (final key in removedKeys) {
      _stepControllers.remove(key)?.dispose();
    }
  }

  List<Map<String, dynamic>> _buildStepUpdates() {
    return _steps.map((step) {
      final stepKey = step['stepKey']?.toString() ?? '';
      final controller = _stepControllers[stepKey];
      if (controller == null) {
        return <String, dynamic>{'stepKey': stepKey, 'status': 'pending'};
      }
      final notes = controller.notesController.text.trim();
      final blockedReason = controller.blockedReasonController.text.trim();
      return <String, dynamic>{
        'stepKey': stepKey,
        'status': controller.status,
        if (notes.isNotEmpty) 'notes': notes,
        if (blockedReason.isNotEmpty) 'blockedReason': blockedReason,
        'metadata': {
          'source': 'frontend_operator',
          'photoUrl': controller.photoUrlController.text.trim(),
        },
      };
    }).toList();
  }

  List<Map<String, dynamic>> _buildAttachments() {
    final attachments = <Map<String, dynamic>>[];
    for (final step in _steps) {
      final stepKey = step['stepKey']?.toString() ?? '';
      final controller = _stepControllers[stepKey];
      if (controller == null) continue;
      final photoUrl = controller.photoUrlController.text.trim();
      if (photoUrl.isEmpty) continue;
      final uri = Uri.tryParse(photoUrl);
      final fallbackName = '$stepKey-photo.jpg';
      final fileName = uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : fallbackName;
      attachments.add({
        'stepKey': stepKey,
        'url': photoUrl,
        'fileName': fileName.isEmpty ? fallbackName : fileName,
        'mimeType': 'image/jpeg',
        'caption': 'Photo checklist pour ${step['title']?.toString() ?? stepKey}',
        'takenAt': DateTime.now().toIso8601String(),
        'metadata': {
          'source': 'frontend_operator',
        },
      });
    }
    return attachments;
  }

  List<Map<String, dynamic>> _buildSignatures() {
    final tenantName = _tenantNameController.text.trim();
    if (tenantName.isEmpty) {
      return const [];
    }
    return [
      {
        'signatureType': 'tenant_confirmation',
        'signerName': tenantName,
        'signerRole': 'Locataire',
        'method': 'typed',
        'signedAt': DateTime.now().toIso8601String(),
        'signatureData': {
          'text': 'Je confirme les éléments saisis dans la checklist.',
        },
        'metadata': {
          'source': 'frontend_operator',
        },
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sessionSummary = _summary;
    final summary = sessionSummary == null ? null : _ChecklistSummary.fromJson(sessionSummary);

    return Scaffold(
      appBar: const ImmoAppBar(title: 'Checklist locataire'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContextCard(
                buildingName: widget.buildingName,
                unitLabel: widget.unitLabel,
                leaseId: widget.leaseId,
                sessionId: _sessionId,
                sessionState: _sessionState,
              ),
              const SizedBox(height: AppSpacing.lg),
              _IntroCard(
                checklistType: _checklistType,
                onChecklistTypeChanged: _hasSession
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _checklistType = value);
                      },
                tenantNameController: _tenantNameController,
                tenantPhoneController: _tenantPhoneController,
                isLocked: _hasSession,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null) ...[
                _ErrorCard(message: _errorMessage!),
                const SizedBox(height: AppSpacing.lg),
              ],
              _ActionBar(
                hasSession: _hasSession,
                isCreating: _isCreating,
                isRefreshing: _isRefreshing,
                isPausing: _isPausing,
                isResuming: _isResuming,
                isSubmitting: _isSubmitting,
                sessionState: _sessionState,
                onCreate: _createSession,
                onRefresh: () => _refreshSummary(managerView: false),
                onPause: _pauseSession,
                onResume: _resumeSession,
                onSubmit: _submitSession,
                pauseReasonController: _pauseReasonController,
                confirmationNoteController: _confirmationNoteController,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Étapes',
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _hasSession
                    ? 'Le contenu ci-dessous est synchronisé avec le contrat backend de checklist.'
                    : 'Créez la session pour charger les étapes depuis le backend.',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_steps.isEmpty)
                const _EmptyStateCard(
                  title: 'Aucune étape chargée',
                  message: 'Créez une checklist pour voir le modèle move-in ou move-out.',
                )
              else
                ..._steps.map((step) {
                  final stepKey = step['stepKey']?.toString() ?? '';
                  final controller = _stepControllers[stepKey];
                  if (controller == null) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ChecklistStepCard(
                      step: step,
                      controller: controller,
                      onStatusChanged: (value) {
                        setState(() => controller.status = value);
                      },
                    ),
                  );
                }),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Résumé gestionnaire',
                style: AppTypography.sectionHeader.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (summary == null)
                const _EmptyStateCard(
                  title: 'Aucun résumé disponible',
                  message: 'Le résumé apparaîtra après la création ou le rafraîchissement de la session.',
                )
              else
                _ManagerSummaryCard(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({
    required this.buildingName,
    required this.unitLabel,
    required this.leaseId,
    required this.sessionId,
    required this.sessionState,
  });

  final String buildingName;
  final String unitLabel;
  final String? leaseId;
  final String? sessionId;
  final String? sessionState;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contexte opérateur',
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Le flux reste limité à la société active, à l’unité courante et au bail associé lorsqu’il existe.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Chip(label: buildingName, color: AppColors.primary),
                _Chip(label: 'Unité $unitLabel', color: AppColors.info),
                _Chip(label: leaseId == null || leaseId!.isEmpty ? 'Sans bail lié' : 'Bail ${_shortId(leaseId)}', color: AppColors.success),
                if (sessionId != null && sessionId!.isNotEmpty)
                  _Chip(label: 'Session ${_shortId(sessionId)}', color: AppColors.textSecondary),
                if (sessionState != null && sessionState!.isNotEmpty)
                  _Chip(label: sessionState!, color: AppColors.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.checklistType,
    required this.onChecklistTypeChanged,
    required this.tenantNameController,
    required this.tenantPhoneController,
    required this.isLocked,
  });

  final String checklistType;
  final ValueChanged<String?>? onChecklistTypeChanged;
  final TextEditingController tenantNameController;
  final TextEditingController tenantPhoneController;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Création / reprise',
              style: AppTypography.sectionHeader.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choisissez le type de checklist, puis complétez les champs du locataire avant de créer la session.',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: checklistType,
                    onChanged: isLocked ? null : onChecklistTypeChanged,
                    decoration: const InputDecoration(labelText: 'Type de checklist'),
                    items: const [
                      DropdownMenuItem(value: 'move_in', child: Text('Entrée')), 
                      DropdownMenuItem(value: 'move_out', child: Text('Sortie')),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: tenantNameController,
                    enabled: !isLocked,
                    decoration: const InputDecoration(
                      labelText: 'Nom du locataire',
                      hintText: 'Ex. Sophie Tremblay',
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: tenantPhoneController,
                    enabled: !isLocked,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      hintText: 'Ex. 514 555-1234',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _FlowChips(),
          ],
        ),
      ),
    );
  }
}

class _FlowChips extends StatelessWidget {
  const _FlowChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: const [
        _Chip(label: 'Mobile-first', color: AppColors.primary),
        _Chip(label: 'Photos et notes par étape', color: AppColors.info),
        _Chip(label: 'Pause / reprise', color: AppColors.warning),
        _Chip(label: 'Résumé gestionnaire', color: AppColors.success),
      ],
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.hasSession,
    required this.isCreating,
    required this.isRefreshing,
    required this.isPausing,
    required this.isResuming,
    required this.isSubmitting,
    required this.sessionState,
    required this.onCreate,
    required this.onRefresh,
    required this.onPause,
    required this.onResume,
    required this.onSubmit,
    required this.pauseReasonController,
    required this.confirmationNoteController,
  });

  final bool hasSession;
  final bool isCreating;
  final bool isRefreshing;
  final bool isPausing;
  final bool isResuming;
  final bool isSubmitting;
  final String? sessionState;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSubmit;
  final TextEditingController pauseReasonController;
  final TextEditingController confirmationNoteController;

  @override
  Widget build(BuildContext context) {
    final isPaused = sessionState == 'paused';
    final canPause = hasSession && !isPaused;
    final canResume = hasSession && isPaused;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: isCreating ? null : onCreate,
              icon: isCreating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check_rounded),
              label: Text(hasSession ? 'Recréer la session' : 'Créer la session'),
            ),
            OutlinedButton.icon(
              onPressed: hasSession && !isRefreshing ? onRefresh : null,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
              label: const Text('Rafraîchir le résumé'),
            ),
            OutlinedButton.icon(
              onPressed: canPause && !isPausing ? onPause : null,
              icon: isPausing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.pause_circle_outline_rounded),
              label: const Text('Mettre en pause'),
            ),
            OutlinedButton.icon(
              onPressed: canResume && !isResuming ? onResume : null,
              icon: isResuming
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_circle_outline_rounded),
              label: const Text('Reprendre'),
            ),
            ElevatedButton.icon(
              onPressed: hasSession && !isSubmitting ? onSubmit : null,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Soumettre au backend'),
            ),
            SizedBox(
              width: 280,
              child: TextField(
                controller: pauseReasonController,
                decoration: const InputDecoration(
                  labelText: 'Raison de pause',
                  hintText: 'Optionnel',
                ),
              ),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                controller: confirmationNoteController,
                decoration: const InputDecoration(
                  labelText: 'Note de confirmation',
                  hintText: 'Résumé court avant soumission',
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistStepCard extends StatelessWidget {
  const _ChecklistStepCard({
    required this.step,
    required this.controller,
    required this.onStatusChanged,
  });

  final Map<String, dynamic> step;
  final _ChecklistStepController controller;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final requiredFields = (step['requiredFields'] as List<dynamic>? ?? const [])
        .map((field) => field.toString())
        .toList();
    final stepStatus = controller.status;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: ExpansionTile(
          initiallyExpanded: stepStatus != 'completed',
          leading: CircleAvatar(
            backgroundColor: _statusColor(stepStatus).withValues(alpha: 0.12),
            child: Icon(_statusIcon(stepStatus), color: _statusColor(stepStatus)),
          ),
          title: Text(
            step['title']?.toString() ?? 'Étape',
            style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            step['description']?.toString() ?? '',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _Chip(label: 'Clé ${step['stepKey']?.toString() ?? ''}', color: AppColors.primary),
                      _Chip(label: stepStatus, color: _statusColor(stepStatus)),
                      for (final field in requiredFields) _Chip(label: field, color: AppColors.info),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: stepStatus,
                    decoration: const InputDecoration(labelText: 'État de l’étape'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('À faire')),
                      DropdownMenuItem(value: 'completed', child: Text('Terminée')),
                      DropdownMenuItem(value: 'blocked', child: Text('Bloquée')),
                      DropdownMenuItem(value: 'skipped', child: Text('Passée')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      onStatusChanged(value);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller.notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Ajoutez les constats liés à cette étape',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller.photoUrlController,
                    decoration: const InputDecoration(
                      labelText: 'URL photo / document',
                      hintText: 'https://…',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller.blockedReasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motif si bloquée',
                      hintText: 'Expliquez le blocage si nécessaire',
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

class _ManagerSummaryCard extends StatelessWidget {
  const _ManagerSummaryCard({required this.summary});

  final _ChecklistSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Chip(label: 'Étapes ${summary.stepCount}', color: AppColors.primary),
                _Chip(label: 'Terminées ${summary.completedStepCount}', color: AppColors.success),
                _Chip(label: 'Bloquées ${summary.blockedStepCount}', color: AppColors.warning),
                _Chip(label: 'Pièces jointes ${summary.attachmentCount}', color: AppColors.info),
                _Chip(label: 'Signatures ${summary.signatureCount}', color: AppColors.textSecondary),
                _Chip(label: summary.isComplete ? 'Complétée' : 'En cours', color: summary.isComplete ? AppColors.success : AppColors.warning),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Dernière activité : ${summary.lastEventAt ?? '—'}',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Étape courante : ${summary.currentStepKey ?? '—'}',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          message,
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      side: BorderSide.none,
      backgroundColor: color.withValues(alpha: 0.12),
      label: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChecklistStepController {
  _ChecklistStepController({required this.stepKey})
      : notesController = TextEditingController(),
        photoUrlController = TextEditingController(),
        blockedReasonController = TextEditingController();

  final String stepKey;
  String status = 'pending';
  final TextEditingController notesController;
  final TextEditingController photoUrlController;
  final TextEditingController blockedReasonController;

  void dispose() {
    notesController.dispose();
    photoUrlController.dispose();
    blockedReasonController.dispose();
  }
}

class _ChecklistSummary {
  const _ChecklistSummary({
    required this.stepCount,
    required this.completedStepCount,
    required this.blockedStepCount,
    required this.pendingStepCount,
    required this.skippedStepCount,
    required this.attachmentCount,
    required this.signatureCount,
    required this.eventCount,
    required this.isComplete,
    required this.isPaused,
    required this.lastEventAt,
    required this.currentStepKey,
    required this.currentStepOrder,
  });

  final int stepCount;
  final int completedStepCount;
  final int blockedStepCount;
  final int pendingStepCount;
  final int skippedStepCount;
  final int attachmentCount;
  final int signatureCount;
  final int eventCount;
  final bool isComplete;
  final bool isPaused;
  final String? lastEventAt;
  final String? currentStepKey;
  final int? currentStepOrder;

  factory _ChecklistSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(String key) => (json[key] as num?)?.toInt() ?? 0;
    return _ChecklistSummary(
      stepCount: parseInt('stepCount'),
      completedStepCount: parseInt('completedStepCount'),
      blockedStepCount: parseInt('blockedStepCount'),
      pendingStepCount: parseInt('pendingStepCount'),
      skippedStepCount: parseInt('skippedStepCount'),
      attachmentCount: parseInt('attachmentCount'),
      signatureCount: parseInt('signatureCount'),
      eventCount: parseInt('eventCount'),
      isComplete: json['isComplete'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      lastEventAt: json['lastEventAt'] as String?,
      currentStepKey: json['currentStepKey'] as String?,
      currentStepOrder: (json['currentStepOrder'] as num?)?.toInt(),
    );
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'completed':
      return Icons.check_circle_rounded;
    case 'blocked':
      return Icons.block_rounded;
    case 'skipped':
      return Icons.next_plan_rounded;
    default:
      return Icons.radio_button_unchecked_rounded;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'completed':
      return AppColors.success;
    case 'blocked':
      return AppColors.warning;
    case 'skipped':
      return AppColors.textMuted;
    default:
      return AppColors.primary;
  }
}

String _shortId(String? value) {
  final normalized = value ?? '';
  if (normalized.length <= 10) return normalized;
  return normalized.substring(0, 10);
}
