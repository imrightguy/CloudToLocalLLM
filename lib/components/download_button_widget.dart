import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/github_release_service.dart';

/// Enhanced download button widget with proper error handling
class DownloadButtonWidget extends StatefulWidget {
  final DownloadOption downloadOption;
  final VoidCallback? onDownloadStarted;
  final Function(String)? onError;

  const DownloadButtonWidget({
    super.key,
    required this.downloadOption,
    this.onDownloadStarted,
    this.onError,
  });

  @override
  State<DownloadButtonWidget> createState() => _DownloadButtonWidgetState();
}

class _DownloadButtonWidgetState extends State<DownloadButtonWidget> {
  bool _isDownloading = false;
  final GitHubReleaseService _releaseService = GitHubReleaseService();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getIconForAsset(widget.downloadOption.name),
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.downloadOption.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.downloadOption.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${widget.downloadOption.formattedSize}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _handleDownload,
                icon: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_isDownloading ? 'Downloading...' : 'Download'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                'Note: Download will start automatically in your browser',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getIconForAsset(String assetName) {
    if (assetName.contains('Setup.exe')) {
      return Icons.install_desktop;
    } else if (assetName.contains('portable.zip')) {
      return Icons.folder_zip;
    } else if (assetName.contains('.sha256')) {
      return Icons.verified;
    }
    return Icons.download;
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Validate the download URL
      if (widget.downloadOption.downloadUrl.isEmpty) {
        throw Exception('Download URL is empty');
      }

      // Check if URL is accessible
      if (!widget.downloadOption.downloadUrl.startsWith(
        'https://github.com/',
      )) {
        throw Exception('Invalid download URL format');
      }

      // Notify that download is starting
      widget.onDownloadStarted?.call();

      // Initiate download
      await _releaseService.downloadFile(
        widget.downloadOption.downloadUrl,
        widget.downloadOption.name,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download started: ${widget.downloadOption.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleDownload,
            ),
          ),
        );
      }

      // Notify error callback
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}

/// Widget to display all available downloads
class DownloadOptionsWidget extends StatefulWidget {
  const DownloadOptionsWidget({super.key});

  @override
  State<DownloadOptionsWidget> createState() => _DownloadOptionsWidgetState();
}

class _DownloadOptionsWidgetState extends State<DownloadOptionsWidget> {
  final GitHubReleaseService _releaseService = GitHubReleaseService();
  List<DownloadOption> _downloadOptions = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDownloadOptions();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading download options...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load downloads',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadDownloadOptions,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_downloadOptions.isEmpty) {
      return const Center(child: Text('No downloads available'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Download CloudToLocalLLM Desktop Client',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ..._downloadOptions.map(
          (option) => DownloadButtonWidget(
            downloadOption: option,
            onDownloadStarted: () {
              debugPrint('Download started: ${option.name}');
            },
            onError: (error) {
              debugPrint('Download error: $error');
            },
          ),
        ),
      ],
    );
  }

  Future<void> _loadDownloadOptions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final options = await _releaseService.getDownloadOptions();
      setState(() {
        _downloadOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}
