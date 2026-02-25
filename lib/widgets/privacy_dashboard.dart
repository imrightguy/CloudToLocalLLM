import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/privacy_storage_manager.dart';
import '../services/enhanced_user_tier_service.dart';
import '../services/platform_service_manager.dart';

/// Privacy dashboard widget showing transparent data storage information
///
/// Displays:
/// - Current storage location (local vs cloud)
/// - Data statistics (conversations, messages, size)
/// - Tier-based feature availability
/// - Platform-specific limitations
/// - Privacy controls and settings
class PrivacyDashboard extends StatefulWidget {
  const PrivacyDashboard({super.key});

  @override
  State<PrivacyDashboard> createState() => _PrivacyDashboardState();
}

class _PrivacyDashboardState extends State<PrivacyDashboard> {
  @override
  void initState() {
    super.initState();
    // Refresh data when dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    final privacyManager = context.read<PrivacyStorageManager>();
    await privacyManager.refreshStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Data Storage'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data statistics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStorageLocationCard(),
            const SizedBox(height: 16),
            _buildDataStatisticsCard(),
            const SizedBox(height: 16),
            _buildTierFeaturesCard(),
            const SizedBox(height: 16),
            _buildPlatformInfoCard(),
            const SizedBox(height: 16),
            _buildPrivacyControlsCard(),
            const SizedBox(height: 16),
            _buildDataManagementCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageLocationCard() {
    return Consumer<PrivacyStorageManager>(
      builder: (context, privacyManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      privacyManager.cloudSyncEnabled
                          ? Icons.cloud
                          : Icons.storage,
                      color: privacyManager.cloudSyncEnabled
                          ? Colors.blue
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Data Storage Location',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: privacyManager.cloudSyncEnabled
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: privacyManager.cloudSyncEnabled
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        privacyManager.cloudSyncEnabled
                            ? Icons.cloud_done
                            : Icons.lock,
                        color: privacyManager.cloudSyncEnabled
                            ? Colors.blue
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          privacyManager.storageLocationDisplay,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: privacyManager.cloudSyncEnabled
                                        ? Colors.blue
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  privacyManager.cloudSyncEnabled
                      ? 'Your conversations are stored locally and optionally synced to encrypted cloud storage.'
                      : 'Your conversations are stored only on this device. No data is transmitted to cloud servers.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (privacyManager.lastSyncTime != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last sync: ${_formatDateTime(privacyManager.lastSyncTime!)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataStatisticsCard() {
    return Consumer<PrivacyStorageManager>(
      builder: (context, privacyManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Data Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Conversations',
                        privacyManager.totalConversations.toString(),
                        Icons.chat,
                        Colors.blue,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Messages',
                        privacyManager.totalMessages.toString(),
                        Icons.message,
                        Colors.green,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Storage Used',
                        privacyManager.databaseSize,
                        Icons.storage,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTierFeaturesCard() {
    return Consumer<EnhancedUserTierService>(
      builder: (context, tierService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      tierService.isPremiumTier
                          ? Icons.star
                          : Icons.star_border,
                      color: tierService.isPremiumTier
                          ? Colors.amber
                          : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tier Features',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: tierService.isPremiumTier
                            ? Colors.amber
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tierService.currentTier.name.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...tierService.tierBenefits.map(
                  (benefit) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(benefit)),
                      ],
                    ),
                  ),
                ),
                if (tierService.tierLimitations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Current Limitations:',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  ...tierService.tierLimitations.map(
                    (limitation) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(limitation)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlatformInfoCard() {
    return Consumer<PlatformServiceManager>(
      builder: (context, platformManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      platformManager.isWeb ? Icons.web : Icons.computer,
                      color: Colors.purple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Platform Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Platform: ${platformManager.platformName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (platformManager.platformLimitations.isNotEmpty) ...[
                  Text(
                    'Platform Limitations:',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.orange),
                  ),
                  const SizedBox(height: 4),
                  ...platformManager.platformLimitations.map(
                    (limitation) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(limitation)),
                        ],
                      ),
                    ),
                  ),
                ],
                if (platformManager.platformRecommendations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recommendations:',
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.blue),
                  ),
                  const SizedBox(height: 4),
                  ...platformManager.platformRecommendations.map(
                    (recommendation) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lightbulb,
                            color: Colors.blue,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(recommendation)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrivacyControlsCard() {
    return Consumer<PrivacyStorageManager>(
      builder: (context, privacyManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy Controls',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Cloud Sync'),
                  subtitle: Text(
                    privacyManager.isCloudSyncAvailable
                        ? 'Sync conversations across devices'
                        : 'Requires premium tier',
                  ),
                  value: privacyManager.cloudSyncEnabled,
                  onChanged: privacyManager.isCloudSyncAvailable
                      ? (value) async {
                          if (value) {
                            await privacyManager.enableCloudSync();
                          } else {
                            await privacyManager.disableCloudSync();
                          }
                        }
                      : null,
                ),
                SwitchListTile(
                  title: const Text('Encryption'),
                  subtitle: Text(
                    privacyManager.isEncryptionAvailable
                        ? 'Encrypt stored conversations'
                        : 'Requires premium tier',
                  ),
                  value: privacyManager.encryptionEnabled,
                  onChanged: privacyManager.isEncryptionAvailable
                      ? (value) async {
                          if (value) {
                            final success =
                                await privacyManager.enableEncryption();
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to enable encryption'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            await privacyManager.disableEncryption();
                          }
                        }
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataManagementCard() {
    return Consumer<PrivacyStorageManager>(
      builder: (context, privacyManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.storage, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Data Management',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Export Conversations'),
                  subtitle: const Text('Download your conversation history'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final exportData =
                          await privacyManager.exportConversations();

                      // Convert to JSON string for export
                      final jsonString = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(exportData);
                      final fileName =
                          'cloudtolocalllm_conversations_${DateTime.now().millisecondsSinceEpoch}.json';

                      // Copy to clipboard for now (file saving requires additional package)
                      await Clipboard.setData(ClipboardData(text: jsonString));

                      messenger.showSnackBar(
                        SnackBar(
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Conversations exported to clipboard'),
                              Text(
                                'Paste into a file named: $fileName',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Export failed: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Permanently delete all conversations'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear All Data'),
                        content: const Text(
                          'This will permanently delete all your conversations. This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();

                              // Show loading indicator
                              if (context.mounted) {
                                await showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const AlertDialog(
                                    content: Row(
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(width: 16),
                                        Text('Clearing data...'),
                                      ],
                                    ),
                                  ),
                                );
                              }

                              try {
                                await privacyManager.clearAllLocalData();

                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'All local data cleared successfully',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.of(
                                    context,
                                  ).pop(); // Close loading dialog
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to clear data: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete All'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
