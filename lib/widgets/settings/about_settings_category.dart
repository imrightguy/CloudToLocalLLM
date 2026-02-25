/// About Settings Category Widget
///
/// Displays application version information and system details
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';
import 'settings_category_widgets.dart';

/// About Settings Category - Version Info and System Details
class AboutSettingsCategory extends SettingsCategoryContentWidget {
  const AboutSettingsCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _AboutSettingsCategoryContent();
  }
}

class _AboutSettingsCategoryContent extends StatefulWidget {
  const _AboutSettingsCategoryContent();

  @override
  State<_AboutSettingsCategoryContent> createState() =>
      _AboutSettingsCategoryContentState();
}

class _AboutSettingsCategoryContentState
    extends State<_AboutSettingsCategoryContent> {
  Map<String, dynamic>? _versionInfo;
  Map<String, dynamic>? _componentVersions;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      // Load main version info
      final versionJson = await rootBundle.loadString('assets/version.json');
      _versionInfo = json.decode(versionJson);

      // Load component versions
      try {
        final componentJson =
            await rootBundle.loadString('assets/component-versions.json');
        _componentVersions = json.decode(componentJson);
      } catch (e) {
        debugPrint('[About] Could not load component versions: $e');
        _componentVersions = null;
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load version information: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAppInfoSection(context),
          const SizedBox(height: 32),
          _buildComponentVersionsSection(context),
          const SizedBox(height: 32),
          _buildBuildInfoSection(context),
        ],
      ),
    );
  }

  Widget _buildAppInfoSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(context, 'Name', 'CloudToLocalLLM'),
            _buildInfoRow(
                context, 'Version', _versionInfo?['version'] ?? 'Unknown'),
            _buildInfoRow(
              context,
              'Build',
              _versionInfo?['build_number'] ?? 'Unknown',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentVersionsSection(BuildContext context) {
    if (_componentVersions == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Component Versions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                context, 'Web', _componentVersions!['web'] ?? 'Unknown'),
            _buildInfoRow(context, 'API Backend',
                _componentVersions!['api'] ?? 'Unknown'),
            _buildInfoRow(context, 'Streaming Proxy',
                _componentVersions!['streaming_proxy'] ?? 'Unknown'),
            _buildInfoRow(context, 'Database',
                _componentVersions!['postgres'] ?? 'Unknown'),
            _buildInfoRow(context, 'Base Image',
                _componentVersions!['base'] ?? 'Unknown'),
            const Divider(height: 24),
            _buildInfoRow(
              context,
              'Last Updated',
              _formatDateTime(_componentVersions!['last_updated']),
              isSubtle: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildInfoSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Build Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              'Git Commit',
              _versionInfo?['git_commit'] ?? 'Unknown',
            ),
            _buildInfoRow(
              context,
              'Build Date',
              _formatDateTime(_versionInfo?['build_date']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool isSubtle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isSubtle
                      ? Theme.of(context).colorScheme.onSurface.withAlpha(153)
                      : null,
                ),
          ),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: isSubtle
                      ? Theme.of(context).colorScheme.onSurface.withAlpha(153)
                      : Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return 'Unknown';
    }
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} UTC';
    } catch (e) {
      return isoString;
    }
  }
}
