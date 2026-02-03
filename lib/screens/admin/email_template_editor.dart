import 'package:flutter/material.dart';
import '../../di/locator.dart' as di;
import '../../services/admin_center_service.dart';
import '../../models/admin_role_model.dart';

/// Email Template Editor Screen for the Admin Center
/// Allows administrators to create, edit, and manage email templates
class EmailTemplateEditor extends StatefulWidget {
  const EmailTemplateEditor({super.key});

  @override
  State<EmailTemplateEditor> createState() => _EmailTemplateEditorState();
}

class _EmailTemplateEditorState extends State<EmailTemplateEditor> {
  // State
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String? _error;
  String? _successMessage;
  List<EmailTemplate> _templates = [];
  EmailTemplate? _selectedTemplate;
  String _searchQuery = '';

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _htmlBodyController = TextEditingController();
  final TextEditingController _textBodyController = TextEditingController();
  final TextEditingController _variablesController = TextEditingController();

  // UI state
  bool _showPreview = false;
  bool _isEditingNew = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _htmlBodyController.dispose();
    _textBodyController.dispose();
    _variablesController.dispose();
    super.dispose();
  }

  /// Load email templates from backend
  Future<void> _loadTemplates() async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.viewConfiguration)) {
      setState(() {
        _error = 'You do not have permission to view email templates';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await adminService.getDio().get(
        '/admin/email/templates',
        queryParameters: {'limit': 100, 'offset': 0},
      );

      final templates = (response.data['data']['templates'] as List)
          .map((json) => EmailTemplate.fromJson(json))
          .toList();

      setState(() {
        _templates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load email templates: $e';
        _isLoading = false;
      });
    }
  }

  /// Create new template
  void _createNewTemplate() {
    setState(() {
      _isEditingNew = true;
      _selectedTemplate = null;
      _nameController.clear();
      _descriptionController.clear();
      _subjectController.clear();
      _htmlBodyController.clear();
      _textBodyController.clear();
      _variablesController.clear();
      _error = null;
      _successMessage = null;
    });
  }

  /// Select template for editing
  void _selectTemplate(EmailTemplate template) {
    setState(() {
      _isEditingNew = false;
      _selectedTemplate = template;
      _nameController.text = template.name;
      _descriptionController.text = template.description ?? '';
      _subjectController.text = template.subject;
      _htmlBodyController.text = template.htmlBody ?? '';
      _textBodyController.text = template.textBody ?? '';
      _variablesController.text = (template.variables ?? []).join(', ');
      _error = null;
      _successMessage = null;
    });
  }

  /// Save template
  Future<void> _saveTemplate() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }

    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to edit email templates';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _successMessage = null;
    });

    try {
      // Parse variables
      final variables = _variablesController.text
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();

      final requestData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'subject': _subjectController.text.trim(),
        'html_body': _htmlBodyController.text.trim(),
        'text_body': _textBodyController.text.trim(),
        'variables': variables,
      };

      await adminService.getDio().post(
            '/admin/email/templates',
            data: requestData,
          );

      setState(() {
        _isSaving = false;
        _successMessage = 'Template saved successfully';
        _isEditingNew = false;
      });

      // Reload templates
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadTemplates();
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to save template: $e';
        _isSaving = false;
      });
    }
  }

  /// Delete template
  Future<void> _deleteTemplate(String templateId) async {
    final adminService = di.serviceLocator.get<AdminCenterService>();

    // Check permission
    if (!adminService.hasPermission(AdminPermission.editConfiguration)) {
      setState(() {
        _error = 'You do not have permission to delete email templates';
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: const Text(
          'Are you sure you want to delete this template? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await adminService.getDio().delete(
            '/admin/email/templates/$templateId',
          );

      setState(() {
        _isDeleting = false;
        _successMessage = 'Template deleted successfully';
        _selectedTemplate = null;
      });

      await _loadTemplates();
    } catch (e) {
      setState(() {
        _error = 'Failed to delete template: $e';
        _isDeleting = false;
      });
    }
  }

  /// Get filtered templates based on search query
  List<EmailTemplate> _getFilteredTemplates() {
    if (_searchQuery.isEmpty) {
      return _templates;
    }

    return _templates
        .where(
          (template) =>
              template.name.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
              (template.description?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                  false),
        )
        .toList();
  }

  /// Render template preview with variables
  String _renderPreview() {
    String html = _htmlBodyController.text;

    // Replace variables with sample values
    final variables = _variablesController.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    for (final variable in variables) {
      html = html.replaceAll('{{$variable}}', '[Sample $variable]');
      html = html.replaceAll('{{{$variable}}}', '[Sample $variable]');
    }

    return html;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Template Editor'), elevation: 0),
      body: Row(
        children: [
          // Left panel: Template list
          SizedBox(width: 300, child: _buildTemplateList()),

          // Divider
          const VerticalDivider(width: 1),

          // Right panel: Template editor or empty state
          Expanded(
            child: _selectedTemplate != null || _isEditingNew
                ? _buildTemplateEditor()
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  /// Build template list panel
  Widget _buildTemplateList() {
    return Column(
      children: [
        // Header with search and create button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Templates',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _createNewTemplate,
                icon: const Icon(Icons.add),
                label: const Text('New Template'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search templates...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ],
          ),
        ),

        // Template list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _templates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.mail_outline,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No templates',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _getFilteredTemplates().length,
                      itemBuilder: (context, index) {
                        final template = _getFilteredTemplates()[index];
                        final isSelected = _selectedTemplate?.id == template.id;

                        return ListTile(
                          title: Text(template.name),
                          subtitle: Text(
                            template.description ?? 'No description',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: isSelected,
                          selectedTileColor: Colors.blue.shade50,
                          onTap: () => _selectTemplate(template),
                          trailing: template.isSystemTemplate
                              ? Tooltip(
                                  message: 'System template',
                                  child: Icon(
                                    Icons.lock,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Build template editor panel
  Widget _buildTemplateEditor() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditingNew ? 'New Template' : 'Edit Template',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!_isEditingNew && _selectedTemplate != null)
                      Text(
                        'Created: ${_formatDate(_selectedTemplate!.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    if (!_isEditingNew && _selectedTemplate != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isDeleting
                            ? null
                            : () => _deleteTemplate(_selectedTemplate!.id),
                        tooltip: 'Delete template',
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          _selectedTemplate = null;
                          _isEditingNew = false;
                        });
                      },
                      tooltip: 'Close editor',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Error message
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _error = null),
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
              ),

            // Success message
            if (_successMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _successMessage!,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _successMessage = null),
                      color: Colors.green.shade700,
                    ),
                  ],
                ),
              ),

            // Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      hintText: 'e.g., Password Reset',
                      border: OutlineInputBorder(),
                      helperText: 'Unique name for this template',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Template name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of this template',
                      border: OutlineInputBorder(),
                      helperText: 'Optional description for reference',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Subject
                  TextFormField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Email Subject',
                      hintText: 'e.g., Reset your password',
                      border: OutlineInputBorder(),
                      helperText: 'Subject line for the email',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email subject is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Variables
                  TextFormField(
                    controller: _variablesController,
                    decoration: const InputDecoration(
                      labelText: 'Template Variables',
                      hintText: 'e.g., user_name, reset_link, expiry_time',
                      border: OutlineInputBorder(),
                      helperText:
                          'Comma-separated list of variables to use in template',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // HTML Body
                  TextFormField(
                    controller: _htmlBodyController,
                    decoration: const InputDecoration(
                      labelText: 'HTML Body',
                      hintText: '<h1>Hello {{user_name}}</h1>...',
                      border: OutlineInputBorder(),
                      helperText:
                          'HTML content. Use {{variable_name}} for placeholders',
                    ),
                    maxLines: 8,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'HTML body is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Text Body
                  TextFormField(
                    controller: _textBodyController,
                    decoration: const InputDecoration(
                      labelText: 'Plain Text Body (Optional)',
                      hintText: 'Plain text version of the email...',
                      border: OutlineInputBorder(),
                      helperText: 'Plain text fallback for email clients',
                    ),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 24),

                  // Preview toggle
                  Row(
                    children: [
                      Checkbox(
                        value: _showPreview,
                        onChanged: (value) {
                          setState(() {
                            _showPreview = value ?? false;
                          });
                        },
                      ),
                      const Text('Show preview'),
                    ],
                  ),

                  // Preview
                  if (_showPreview) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: SelectableText(
                              _renderPreview(),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedTemplate = null;
                            _isEditingNew = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveTemplate,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Template'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state when no template is selected
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No template selected',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a template from the list or create a new one',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  /// Format date to readable string
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Email Template model
class EmailTemplate {
  final String id;
  final String name;
  final String? description;
  final String subject;
  final String? htmlBody;
  final String? textBody;
  final List<String>? variables;
  final bool isSystemTemplate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmailTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.subject,
    this.htmlBody,
    this.textBody,
    this.variables,
    required this.isSystemTemplate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EmailTemplate.fromJson(Map<String, dynamic> json) {
    return EmailTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      subject: json['subject'] ?? '',
      htmlBody: json['html_body'],
      textBody: json['text_body'],
      variables: List<String>.from(json['variables'] ?? []),
      isSystemTemplate: json['is_system_template'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}
