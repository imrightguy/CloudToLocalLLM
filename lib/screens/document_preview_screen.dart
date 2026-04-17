import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../services/document_service.dart';
import '../theme/app_colors.dart';

class DocumentPreviewScreen extends StatefulWidget {
  const DocumentPreviewScreen({super.key, required this.document});

  final DocumentItem document;

  @override
  State<DocumentPreviewScreen> createState() => _DocumentPreviewScreenState();
}

class _DocumentPreviewScreenState extends State<DocumentPreviewScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.fileName),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (doc.fileUrl != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Télécharger',
              onPressed: _download,
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Partager',
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Supprimer',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPreviewArea(doc),
            const SizedBox(height: 24),
            _buildMetadataSection(doc),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea(DocumentItem doc) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: doc.documentType.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                doc.isPdf
                    ? Icons.picture_as_pdf
                    : doc.isImage
                        ? Icons.image_outlined
                        : Icons.insert_drive_file_outlined,
                size: 36,
                color: doc.documentType.color,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              doc.fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              doc.fileSizeLabel,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFile,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Ouvrir le fichier'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.surface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataSection(DocumentItem doc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Informations du document',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoRow(Icons.label_outline, 'Type', doc.documentType.label),
        if (doc.description != null && doc.description!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow(Icons.notes_outlined, 'Description', doc.description!),
        ],
        const SizedBox(height: 12),
        _buildInfoRow(Icons.apartment_outlined, 'Emplacement', doc.locationLabel),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.storage_outlined, 'Taille', doc.fileSizeLabel),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.insert_drive_file_outlined,
          'Format',
          _formatMimeType(doc.fileType),
        ),
        if (doc.createdAt != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.calendar_today_outlined,
            'Date de téléversement',
            DateFormat('d MMMM yyyy à HH:mm', 'fr').format(doc.createdAt!),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMimeType(String mimeType) {
    final lower = mimeType.toLowerCase();
    if (lower == 'application/pdf') return 'PDF';
    if (lower.startsWith('image/jpeg') || lower.startsWith('image/jpg')) return 'JPEG';
    if (lower.startsWith('image/png')) return 'PNG';
    if (lower.startsWith('image/gif')) return 'GIF';
    if (lower.startsWith('image/webp')) return 'WebP';
    return mimeType;
  }

  void _openFile() {
    final url = widget.document.fileUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fichier non disponible'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ouverture du fichier...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _download() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Téléchargement en cours...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _share() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Partage en cours...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le document'),
        content: Text(
          'Voulez-vous vraiment supprimer « ${widget.document.fileName }»? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: _isDeleting ? null : () async {
              Navigator.of(ctx).pop();
              await _deleteDocument();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument() async {
    final id = widget.document.id;
    if (id == null) return;

    setState(() => _isDeleting = true);
    try {
      await DocumentService.instance.deleteDocument(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document supprimé'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
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
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
