import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../components/download_button_widget.dart';
import '../services/github_release_service.dart';

/// Test screen for download functionality
class DownloadTestScreen extends StatefulWidget {
  const DownloadTestScreen({super.key});

  @override
  State<DownloadTestScreen> createState() => _DownloadTestScreenState();
}

class _DownloadTestScreenState extends State<DownloadTestScreen> {
  final GitHubReleaseService _releaseService = GitHubReleaseService();
  GitHubRelease? _latestRelease;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReleaseInfo();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Test'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReleaseInfo,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download System Status',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow('Platform', kIsWeb ? 'Web' : 'Desktop'),
                    _buildStatusRow(
                      'GitHub API',
                      _isLoading
                          ? 'Checking...'
                          : (_error == null ? 'Connected' : 'Error'),
                    ),
                    if (_latestRelease != null) ...[
                      _buildStatusRow(
                        'Latest Version',
                        _latestRelease!.tagName,
                      ),
                      _buildStatusRow(
                        'Release Date',
                        _formatDate(_latestRelease!.publishedAt),
                      ),
                      _buildStatusRow(
                        'Assets Available',
                        '${_latestRelease!.assets.length}',
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Error Display
            if (_error != null)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error, color: Colors.red[700]),
                          const SizedBox(width: 8),
                          Text(
                            'Error Loading Release Data',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Download Options
            if (!_isLoading && _error == null) const DownloadOptionsWidget(),

            // Loading Indicator
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),

            // Manual Download Links (Fallback)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manual Download Links',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'If the download buttons above don\'t work, you can access the files directly:',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    _buildManualLink(
                      'GitHub Releases Page',
                      'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases',
                      Icons.open_in_new,
                    ),
                    _buildManualLink(
                      'Latest Release (Direct)',
                      'https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest',
                      Icons.download,
                    ),
                  ],
                ),
              ),
            ),

            // Debug Information
            if (kDebugMode && _latestRelease != null)
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Information',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ..._latestRelease!.assets.map(
                        (asset) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'URL: ${asset.browserDownloadUrl}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Text(
                                'Size: ${(asset.size / (1024 * 1024)).toStringAsFixed(1)}MB, Downloads: ${asset.downloadCount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildManualLink(String title, String url, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _openUrl(url),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUrl(String url) {
    if (kIsWeb) {
      // For web, open in new tab
      // This would need proper URL launcher implementation
      debugPrint('Opening URL: $url');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadReleaseInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final release = await _releaseService.getLatestRelease();
      setState(() {
        _latestRelease = release;
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
