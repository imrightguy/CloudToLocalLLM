import 'package:flutter/material.dart';

import '../services/message_templates_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/immo_app_bar.dart';
import '../widgets/loading_state.dart';
import '../widgets/error_state.dart';

/// Settings sub-screen to customize the automatic message templates triggered
/// by PlexFlow webhooks (departure / arrival / lease SMS + vacant/occupied email).
class AutomaticMessagesScreen extends StatefulWidget {
  const AutomaticMessagesScreen({super.key});

  @override
  State<AutomaticMessagesScreen> createState() =>
      _AutomaticMessagesScreenState();
}

class _AutomaticMessagesScreenState extends State<AutomaticMessagesScreen> {
  bool _isLoading = true;
  Object? _lastError;
  List<Map<String, dynamic>> _templates = [];

  // Per-event-type controllers + state.
  final Map<String, TextEditingController> _bodyCtrls = {};
  final Map<String, TextEditingController> _subjectCtrls = {};
  final Map<String, bool> _active = {};
  final Set<String> _saving = {};

  static const Map<String, String> _labels = {
    'tenant_deactivated': 'Départ du locataire',
    'tenant_activated': 'Arrivée du locataire',
    'lease_created': 'Bail créé',
    'lease_renewed': 'Renouvellement de bail',
    'unit_vacant': 'Unité vacante',
    'unit_occupied': 'Unité occupée',
  };

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    for (final c in _bodyCtrls.values) {
      c.dispose();
    }
    for (final c in _subjectCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
    });
    try {
      final templates = await MessageTemplatesService.instance.list();
      if (!mounted) return;
      for (final t in templates) {
        final eventType = t['eventType']?.toString() ?? '';
        _bodyCtrls[eventType] =
            TextEditingController(text: t['body'] as String? ?? '');
        _subjectCtrls[eventType] =
            TextEditingController(text: t['subject'] as String? ?? '');
        _active[eventType] = t['isActive'] as bool? ?? true;
      }
      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastError = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _save(Map<String, dynamic> template) async {
    final eventType = template['eventType']?.toString() ?? '';
    final isEmail = (template['channel'] as String?) == 'email';
    setState(() => _saving.add(eventType));
    try {
      await MessageTemplatesService.instance.update(
        eventType,
        body: _bodyCtrls[eventType]?.text.trim(),
        subject: isEmail ? _subjectCtrls[eventType]?.text.trim() : null,
        isActive: _active[eventType],
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modèle enregistré'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving.remove(eventType));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ImmoAppBar(title: 'Messages automatiques'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const ListSkeleton(showSearchBar: false);
    if (_lastError != null) {
      return ErrorState(error: _lastError!, onRetry: _fetch);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'Personnalisez les messages envoyés automatiquement lorsqu\'un événement PlexFlow est reçu.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: const Text(
            'Variables disponibles: {tenantName}, {unitLabel}, {buildingName}, {date}',
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ..._templates.map(_templateCard),
      ],
    );
  }

  Widget _templateCard(Map<String, dynamic> template) {
    final eventType = template['eventType']?.toString() ?? '';
    final channel = template['channel'] as String? ?? 'sms';
    final isEmail = channel == 'email';
    final label = _labels[eventType] ?? eventType;
    final saving = _saving.contains(eventType);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEmail ? Icons.email_outlined : Icons.sms_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  isEmail ? 'Email' : 'SMS',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Switch(
                  value: _active[eventType] ?? true,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _active[eventType] = v),
                ),
                Text(
                  (_active[eventType] ?? true) ? 'Activé' : 'Désactivé',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            if (isEmail) ...[
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _subjectCtrls[eventType],
                decoration: const InputDecoration(
                  labelText: 'Objet',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _bodyCtrls[eventType],
              maxLines: 4,
              decoration: InputDecoration(
                labelText: isEmail ? 'Corps du courriel' : 'Message SMS',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: saving ? null : () => _save(template),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusControl),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
