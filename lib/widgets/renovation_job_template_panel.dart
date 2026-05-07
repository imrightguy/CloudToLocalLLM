import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class RenovationJobTemplatePanel extends StatefulWidget {
  const RenovationJobTemplatePanel({super.key});

  @override
  State<RenovationJobTemplatePanel> createState() => _RenovationJobTemplatePanelState();
}

class _RenovationJobTemplatePanelState extends State<RenovationJobTemplatePanel> {
  static const String _companyId = '388be569-9d9d-46e2-b548-7bf0167cb11b';

  late Future<List<RenovationJobTemplate>> _templatesFuture;

  @override
  void initState() {
    super.initState();
    _templatesFuture = _loadTemplates();
  }

  Future<List<RenovationJobTemplate>> _loadTemplates() async {
    final response = await ApiService.instance.get('/companies/$_companyId/renovation-job-templates');
    final data = response['data'];
    if (data is! List) {
      return const [];
    }
    return data
        .whereType<Map>()
        .map((item) => RenovationJobTemplate.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  void _reload() {
    setState(() {
      _templatesFuture = _loadTemplates();
    });
  }

  Future<void> _saveTemplate({RenovationJobTemplate? template}) async {
    final result = await showDialog<RenovationJobTemplateFormResult>(
      context: context,
      builder: (context) => _RenovationJobTemplateDialog(template: template),
    );
    if (result == null) {
      return;
    }

    final payload = result.toPayload();
    if (template == null) {
      await ApiService.instance.post('/companies/$_companyId/renovation-job-templates', payload);
    } else {
      await ApiService.instance.patch('/companies/$_companyId/renovation-job-templates/${template.id}', payload);
    }
    if (!mounted) {
      return;
    }
    _reload();
  }

  Future<void> _toggleFavorite(RenovationJobTemplate template) async {
    await ApiService.instance.patch('/companies/$_companyId/renovation-job-templates/${template.id}', {
      'isFavorite': !template.isFavorite,
    });
    if (!mounted) {
      return;
    }
    _reload();
  }

  void _openOrderPreview(RenovationJobTemplate template) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final shoppingList = [
          ...template.materials,
          ...template.suggestedMissingItems,
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                  'Préparer la commande',
                  style: AppTypography.sectionHeader.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  template.name,
                  style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Liste d\'achat',
                  style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: shoppingList.map((item) => Chip(label: Text(item))).toList(),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Liens produits',
                  style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (template.manualProductLinks.isEmpty)
                  Text(
                    'Aucun lien manuel pour ce modèle.',
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  )
                else
                  ...template.manualProductLinks.map(
                    (link) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link_rounded, color: AppColors.primary),
                        title: Text(link.label),
                        subtitle: Text(link.url),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RenovationJobTemplate>>(
      future: _templatesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Impossible de charger les modèles',
                    style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    snapshot.error.toString(),
                    style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        final templates = snapshot.data ?? const <RenovationJobTemplate>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Modèles réutilisables',
                            style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sauvegardez des gabarits de travaux avec matériaux, notes, favoris et liens produits manuels.',
                            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => _saveTemplate(),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nouveau modèle'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (templates.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aucun modèle enregistré',
                        style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Créez un premier modèle de travaux pour garder vos matériaux et liens produits à portée de main.',
                        style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: () => _saveTemplate(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Créer un modèle'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...templates.map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RenovationJobTemplateCard(
                    template: template,
                    onToggleFavorite: () => _toggleFavorite(template),
                    onEdit: () => _saveTemplate(template: template),
                    onOrderPreview: () => _openOrderPreview(template),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RenovationJobTemplateCard extends StatelessWidget {
  const _RenovationJobTemplateCard({
    required this.template,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onOrderPreview,
  });

  final RenovationJobTemplate template;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onOrderPreview;

  @override
  Widget build(BuildContext context) {
    final linkCount = template.manualProductLinks.length;
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              template.name,
                              style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
                            ),
                          ),
                          IconButton(
                            onPressed: onToggleFavorite,
                            icon: Icon(
                              template.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: template.isFavorite ? AppColors.warning : AppColors.textSecondary,
                            ),
                            tooltip: template.isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
                          ),
                        ],
                      ),
                      if ((template.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          template.description!,
                          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                _Badge(label: template.isFavorite ? 'Favori' : 'Modèle', color: template.isFavorite ? AppColors.warning : AppColors.primary),
                _Badge(label: '${template.materials.length} matériaux', color: AppColors.info),
                _Badge(label: '$linkCount lien${linkCount == 1 ? '' : 's'} produit', color: AppColors.success),
              ],
            ),
            if (template.materials.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Matériaux',
                style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: template.materials.map((material) => Chip(label: Text(material))).toList(),
              ),
            ],
            if ((template.notes ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Notes',
                style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                template.notes!,
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Suggestions d\'items manquants',
              style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (template.suggestedMissingItems.isEmpty)
              Text(
                'Aucune suggestion automatique pour ce contexte.',
                style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: template.suggestedMissingItems.map((item) => Chip(label: Text(item))).toList(),
              ),
            if (template.manualProductLinks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Liens produits manuels',
                style: AppTypography.bodyBold.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...template.manualProductLinks.map(
                (link) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link_rounded, color: AppColors.primary),
                    title: Text(link.label),
                    subtitle: Text(link.url),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: onOrderPreview,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Préparer la commande'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Dupliquer / éditer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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

class _RenovationJobTemplateDialog extends StatefulWidget {
  const _RenovationJobTemplateDialog({this.template});

  final RenovationJobTemplate? template;

  @override
  State<_RenovationJobTemplateDialog> createState() => _RenovationJobTemplateDialogState();
}

class _RenovationJobTemplateDialogState extends State<_RenovationJobTemplateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _materialsController;
  late final TextEditingController _notesController;
  late final TextEditingController _linksController;
  bool _isFavorite = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _nameController = TextEditingController(text: template?.name ?? '');
    _descriptionController = TextEditingController(text: template?.description ?? '');
    _materialsController = TextEditingController(text: (template?.materials ?? const []).join('\n'));
    _notesController = TextEditingController(text: template?.notes ?? '');
    _linksController = TextEditingController(
      text: template == null
          ? ''
          : template.manualProductLinks.map((link) => [link.label, link.url, link.note ?? ''].where((part) => part.trim().isNotEmpty).join('|')).join('\n'),
    );
    _isFavorite = template?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _materialsController.dispose();
    _notesController.dispose();
    _linksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.template == null ? 'Nouveau modèle' : 'Modifier le modèle'),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du modèle'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _materialsController,
                decoration: const InputDecoration(
                  labelText: 'Matériaux',
                  hintText: 'Un item par ligne',
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Notes de chantier, précisions ou rappels',
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _linksController,
                decoration: const InputDecoration(
                  labelText: 'Liens produits manuels',
                  hintText: 'Libellé|https://...|note optionnelle',
                ),
                minLines: 3,
                maxLines: 6,
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isFavorite,
                onChanged: (value) => setState(() => _isFavorite = value),
                title: const Text('Ajouter aux favoris'),
                subtitle: const Text('Mettre le modèle en évidence pour le retrouver rapidement'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom du modèle est requis.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final result = RenovationJobTemplateFormResult(
        name: name,
        description: _descriptionController.text.trim(),
        materials: _materialsController.text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList(),
        notes: _notesController.text.trim(),
        manualProductLinks: _linksController.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .map(_TemplateLinkInput.parse)
            .whereType<_TemplateLinkInput>()
            .toList(),
        isFavorite: _isFavorite,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }
}

class RenovationJobTemplateFormResult {
  const RenovationJobTemplateFormResult({
    required this.name,
    required this.description,
    required this.materials,
    required this.notes,
    required this.manualProductLinks,
    required this.isFavorite,
  });

  final String name;
  final String description;
  final List<String> materials;
  final String notes;
  final List<_TemplateLinkInput> manualProductLinks;
  final bool isFavorite;

  Map<String, dynamic> toPayload() => {
        'name': name,
        'description': description.isEmpty ? null : description,
        'materials': materials,
        'notes': notes.isEmpty ? null : notes,
        'manualProductLinks': manualProductLinks.map((link) => link.toJson()).toList(),
        'isFavorite': isFavorite,
      };
}

class RenovationJobTemplate {
  const RenovationJobTemplate({
    required this.id,
    required this.name,
    required this.isFavorite,
    required this.materials,
    required this.manualProductLinks,
    required this.suggestedMissingItems,
    this.description,
    this.notes,
  });

  final String id;
  final String name;
  final String? description;
  final bool isFavorite;
  final List<String> materials;
  final String? notes;
  final List<_TemplateLinkInput> manualProductLinks;
  final List<String> suggestedMissingItems;

  factory RenovationJobTemplate.fromJson(Map<String, dynamic> json) {
    return RenovationJobTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Modèle sans nom',
      description: json['description'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      materials: _stringList(json['materials']),
      notes: json['notes'] as String?,
      manualProductLinks: _linkList(json['manualProductLinks']),
      suggestedMissingItems: _stringList(json['suggestedMissingItems']),
    );
  }
}

class _TemplateLinkInput {
  const _TemplateLinkInput({required this.label, required this.url, this.note});

  final String label;
  final String url;
  final String? note;

  factory _TemplateLinkInput.parse(String line) {
    final parts = line.split('|').map((part) => part.trim()).where((part) => part.isNotEmpty).toList();
    if (parts.length < 2) {
      return _TemplateLinkInput(label: line, url: line);
    }
    return _TemplateLinkInput(
      label: parts[0],
      url: parts[1],
      note: parts.length > 2 ? parts.sublist(2).join(' | ') : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'url': url,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
}

List<_TemplateLinkInput> _linkList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .map((item) => _TemplateLinkInput(
            label: item['label']?.toString() ?? item['url']?.toString() ?? 'Lien manuel',
            url: item['url']?.toString() ?? '',
            note: item['note']?.toString(),
          ))
      .where((item) => item.url.isNotEmpty)
      .toList();
}
