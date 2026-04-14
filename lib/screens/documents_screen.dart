import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/document_service.dart';
import 'document_preview_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/immo_app_bar.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentItem> _documents = [];
  List<DocumentItem> _filteredDocuments = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isUploading = false;
  double _uploadProgress = 0;
  final TextEditingController _searchController = TextEditingController();
  DocumentType? _selectedTypeFilter;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredDocuments = _documents.where((doc) {
        final matchesSearch = query.isEmpty ||
            doc.fileName.toLowerCase().contains(query) ||
            (doc.description?.toLowerCase().contains(query) ?? false);
        final matchesType =
            _selectedTypeFilter == null || doc.documentType == _selectedTypeFilter;
        return matchesSearch && matchesType;
      }).toList();
    });
  }

  Future<void> _fetchDocuments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final documents = await DocumentService.instance.getDocuments();
      setState(() {
        _documents = documents;
        _filteredDocuments = documents;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Map<String, List<DocumentItem>> _groupByLocation() {
    final grouped = <String, List<DocumentItem>>{};
    for (final doc in _filteredDocuments) {
      final key = doc.locationLabel;
      grouped.putIfAbsent(key, () => []).add(doc);
    }
    return grouped;
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _UploadDocumentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ImmoAppBar(title: 'Documents', actions: actions: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _uploadProgress > 0 ? _uploadProgress : null,
                  ),
                ),
              ),
            ),
        ])
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showUploadDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Impossible de charger les documents',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
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
              onPressed: _fetchDocuments,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDocuments,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Rechercher par nom ou description...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildFilterChips(),
            const SizedBox(height: 16),
            if (_filteredDocuments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'Aucun document trouvé',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ..._buildGroupedList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip(null, 'Tous'),
          const SizedBox(width: 8),
          for (final type in DocumentType.values) ...[
            _buildFilterChip(type, type.label),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(DocumentType? type, String label) {
    final isSelected = _selectedTypeFilter == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedTypeFilter = type;
        });
        _applyFilters();
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.1),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }

  List<Widget> _buildGroupedList() {
    final grouped = _groupByLocation();
    final widgets = <Widget>[];

    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            entry.key,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
      for (final doc in entry.value) {
        widgets.add(_buildDocumentCard(doc));
      }
      widgets.add(const SizedBox(height: 16));
    }

    return widgets;
  }

  Widget _buildDocumentCard(DocumentItem doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DocumentPreviewScreen(document: doc),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: doc.documentType.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    doc.documentType.icon,
                    color: doc.documentType.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.fileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: doc.documentType.color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              doc.documentType.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: doc.documentType.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            doc.fileSizeLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (doc.createdAt != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('d MMM yyyy', 'fr').format(doc.createdAt!),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadDocumentSheet extends StatefulWidget {
  const _UploadDocumentSheet();

  @override
  State<_UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<_UploadDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  DocumentType _selectedType = DocumentType.lease;
  String? _selectedBuildingId;
  String? _selectedBuildingName;
  String? _selectedUnitId;
  String? _selectedUnitLabel;

  String? _pickedFileName;
  String? _pickedFileType;
  Uint8List? _pickedFileBytes;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePickerWrapper.pickFiles();
      if (result != null) {
        setState(() {
          _pickedFileName = result.fileName;
          _pickedFileType = result.fileType;
          _pickedFileBytes = result.fileBytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_pickedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un fichier'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await DocumentService.instance.uploadDocument(
        fileName: _pickedFileName!,
        fileType: _pickedFileType!,
        fileBytes: _pickedFileBytes!,
        documentType: _selectedType.apiValue,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        buildingId: _selectedBuildingId,
        unitId: _selectedUnitId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document téléversé avec succès'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Téléverser un document',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _pickedFileName != null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _pickedFileName != null
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      _pickedFileName != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      color: _pickedFileName != null
                          ? AppColors.primary
                          : AppColors.textMuted,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFileName ?? 'Sélectionner un fichier',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _pickedFileName != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_pickedFileName == null)
                            const Text(
                              'PDF, images (JPG, PNG, WebP)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<DocumentType>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Type de document',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: DocumentType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedType = v);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes_outlined),
                hintText: 'Description optionnelle...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Téléverser',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FilePickerWrapper {
  static Future<_PickedFile?> pickFiles() async {
    try {
      final result = await FilePickerPlatform.pickFiles();
      if (result == null) return null;
      return _PickedFile(
        fileName: result['name'] as String,
        fileType: result['type'] as String,
        fileBytes: Uint8List.fromList(result['bytes'] as List<int>),
      );
    } catch (_) {
      return null;
    }
  }
}

class FilePickerPlatform {
  static Future<Map<String, dynamic>?> pickFiles() async {
    return null;
  }
}

class _PickedFile {
  final String fileName;
  final String fileType;
  final Uint8List fileBytes;

  const _PickedFile({
    required this.fileName,
    required this.fileType,
    required this.fileBytes,
  });
}
