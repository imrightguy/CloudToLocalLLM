import 'package:flutter/material.dart';

import '../services/property_photo_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/property_photo_upload_sheet.dart';

class PropertyPhotosScreen extends StatefulWidget {
  const PropertyPhotosScreen({
    super.key,
    required this.buildingId,
    required this.buildingName,
    this.unitId,
    this.unitLabel,
  });

  final String buildingId;
  final String buildingName;
  final String? unitId;
  final String? unitLabel;

  @override
  State<PropertyPhotosScreen> createState() => _PropertyPhotosScreenState();
}

class _PropertyPhotosScreenState extends State<PropertyPhotosScreen> {
  bool _isLoading = true;
  Object? _lastError;
  List<PropertyPhoto> _photos = [];
  String? _selectedUseCase;
  int _page = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  static const _useCases = [
    {'value': null, 'label': 'Toutes'},
    {'value': 'general', 'label': 'Général'},
    {'value': 'exterior', 'label': 'Extérieur'},
    {'value': 'interior', 'label': 'Intérieur'},
    {'value': 'renovation', 'label': 'Rénovation'},
    {'value': 'marketing', 'label': 'Marketing'},
    {'value': 'departure', 'label': 'Départ'},
    {'value': 'arrival', 'label': 'Arrivée'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _fetchPhotos() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
      _page = 1;
    });

    try {
      final result = widget.unitId != null
          ? await PropertyPhotoService.instance.getPhotosByUnit(
              widget.unitId!,
              page: 1,
              limit: 30,
            )
          : await PropertyPhotoService.instance.getPhotosByBuilding(
              widget.buildingId,
              useCase: _selectedUseCase,
              page: 1,
              limit: 30,
            );

      if (!mounted) return;
      setState(() {
        _photos = result.photos;
        _hasMore = result.photos.length >= result.limit;
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

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _page++;

    try {
      final result = widget.unitId != null
          ? await PropertyPhotoService.instance.getPhotosByUnit(
              widget.unitId!,
              page: _page,
              limit: 30,
            )
          : await PropertyPhotoService.instance.getPhotosByBuilding(
              widget.buildingId,
              useCase: _selectedUseCase,
              page: _page,
              limit: 30,
            );

      if (!mounted) return;
      setState(() {
        _photos.addAll(result.photos);
        _hasMore = result.photos.length >= result.limit;
      });
    } catch (_) {
      _page--;
    }
  }

  void _onUseCaseChanged(String? value) {
    setState(() => _selectedUseCase = value);
    _fetchPhotos();
  }

  Future<void> _openUploadSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        ),
        child: PropertyPhotoUploadSheet(
          initialBuildingName: widget.buildingName,
          initialUnitLabel: widget.unitLabel ?? '',
          apartmentLabel: widget.unitLabel,
          contextSource: const ApiPropertyPhotoContextSource(),
          photoUploader: ApiPropertyPhotoUploader(),
          photoPicker: const FilePickerPhotoPicker(),
        ),
      ),
    );

    if (result == true && mounted) {
      _fetchPhotos();
    }
  }

  void _openPhotoViewer(PropertyPhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PhotoViewer(photo: photo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.unitLabel != null
        ? 'Photos — ${widget.buildingName} #${widget.unitLabel}'
        : 'Photos — ${widget.buildingName}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPhotos,
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openUploadSheet,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Ajouter photos'),
      ),
      body: Column(
        children: [
          if (widget.unitId == null)
            _buildUseCaseFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildUseCaseFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: _useCases.map((uc) {
          final isSelected = _selectedUseCase == uc['value'];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(uc['label'] as String),
              selected: isSelected,
              onSelected: (_) => _onUseCaseChanged(uc['value']),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _photos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_lastError != null && _photos.isEmpty) {
      return ErrorState(
        error: _lastError!,
        onRetry: _fetchPhotos,
      );
    }

    if (_photos.isEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Aucune photo',
        description: 'Ajoutez des photos pour documenter ce bâtiment.',
        ctaLabel: 'Ajouter des photos',
        onCtaPressed: _openUploadSheet,
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPhotos,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.md),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _crossAxisCount(context),
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1,
        ),
        itemCount: _photos.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _photos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildPhotoTile(_photos[index]);
        },
      ),
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 1200) return 4;
    if (width > 800) return 3;
    return 2;
  }

  Widget _buildPhotoTile(PropertyPhoto photo) {
    return GestureDetector(
      onTap: () => _openPhotoViewer(photo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              photo.url,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: AppColors.surfaceVariant,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        photo.roomContext ?? photo.useCase ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (photo.capturedAt != null)
                      Text(
                        _formatDate(photo.capturedAt!),
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.photo});

  final PropertyPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          photo.fileName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.network(
            photo.url,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
