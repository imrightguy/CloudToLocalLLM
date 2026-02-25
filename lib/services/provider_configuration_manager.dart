library;

/// Provider Configuration Manager
/// Manages local LLM provider configurations with Drift database persistence

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/di/locator.dart';
import 'package:cloudtolocalllm/database/local_brain.dart';
import 'package:drift/drift.dart';

class ProviderConfigurationManager {
  ProviderConfigurationManager();

  bool _isInitialized = false;

  /// Initialize the manager (must be called before use)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final db = serviceLocator<LocalBrain>();

      // Create the llm_providers table if it doesn't exist (for migration before drift codegen)
      await _ensureProvidersTableExists(db);

      _isInitialized = true;
      debugPrint('[ProviderConfig] Initialized successfully');
    } catch (e) {
      debugPrint('[ProviderConfig] Initialization error: $e');
      rethrow;
    }
  }

  /// Ensure the llm_providers table exists
  Future<void> _ensureProvidersTableExists(LocalBrain db) async {
    try {
      // Try to query the table - if it fails, create it
      await db
          .customSelect(
            'SELECT COUNT(*) FROM llm_providers',
          )
          .get();
    } catch (e) {
      debugPrint(
          '[ProviderConfig] llm_providers table does not exist, creating it...');
      await db.customUpdate('''
        CREATE TABLE IF NOT EXISTS llm_providers (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          url TEXT NOT NULL,
          is_local INTEGER NOT NULL DEFAULT 1,
          is_default INTEGER NOT NULL DEFAULT 0,
          version TEXT,
          config TEXT,
          created_at TEXT NOT NULL DEFAULT (datetime('now')),
          updated_at TEXT NOT NULL DEFAULT (datetime('now'))
        )
      ''');
      debugPrint('[ProviderConfig] llm_providers table created');
    }
  }

  /// Get all configured providers as ProviderInfo
  Future<List<ProviderInfo>> getAllProviders() async {
    try {
      final db = serviceLocator<LocalBrain>();

      // Use custom query since LlmProviders table might not be in generated code yet
      final results = await db
          .customSelect(
            'SELECT id, name, type, url, is_local, is_default, version FROM llm_providers',
          )
          .get();

      return results.map((row) {
        return ProviderInfo(
          id: row.read<String>('id'),
          name: row.read<String>('name'),
          type: _stringToProviderType(row.read<String>('type')),
          url: row.read<String>('url'),
          isLocal: row.read<bool>('is_local'),
          isAvailable: true, // Assume available if in database
          version: row.read<String?>('version'),
        );
      }).toList();
    } catch (e) {
      debugPrint('[ProviderConfig] Error getting providers: $e');
      return [];
    }
  }

  /// Get all configurations (legacy method for backward compatibility)
  List<ProviderConfiguration> getAllConfigurations() {
    // Return empty list - this is a legacy method
    // Use getAllProviders() instead which returns Future
    return [];
  }

  /// Check if a provider is configured
  bool isProviderConfigured(String providerId) {
    // This is synchronous but database access is async
    // For now, return false - the async version should be used
    return false;
  }

  /// Check if any providers are configured (async version)
  Future<bool> hasAnyProviders() async {
    try {
      final db = serviceLocator<LocalBrain>();
      final results = await db
          .customSelect(
            'SELECT COUNT(*) as count FROM llm_providers',
          )
          .get();
      return results.first.read<int>('count') > 0;
    } catch (e) {
      debugPrint('[ProviderConfig] Error checking providers: $e');
      return false;
    }
  }

  /// Save a provider configuration
  Future<void> saveProvider({
    required String name,
    required ProviderType type,
    required String url,
    required bool isLocal,
    bool isDefault = false,
    String? version,
  }) async {
    try {
      final db = serviceLocator<LocalBrain>();

      // Generate ID from name and type
      final id = '${type.name}_${name.toLowerCase().replaceAll(' ', '_')}';

      // If this is the first provider or isDefault is true, make it the default
      final hasExisting = await hasAnyProviders();
      final shouldBeDefault = isDefault || !hasExisting;

      // Use custom INSERT with ON CONFLICT UPDATE
      await db.customUpdate(
        '''INSERT INTO llm_providers (id, name, type, url, is_local, is_default, version, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
           ON CONFLICT(id) DO UPDATE SET
             name = excluded.name,
             type = excluded.type,
             url = excluded.url,
             is_local = excluded.is_local,
             is_default = excluded.is_default,
             version = excluded.version,
             updated_at = datetime('now')''',
        variables: [
          Variable(id),
          Variable(name),
          Variable(type.name),
          Variable(url),
          Variable(isLocal ? 1 : 0),
          Variable(shouldBeDefault ? 1 : 0),
          Variable(version)
        ],
      );

      // If this should be default, ensure no other providers are marked as default
      if (shouldBeDefault) {
        await db.customUpdate(
          'UPDATE llm_providers SET is_default = 0 WHERE id != ?',
          variables: [Variable(id)],
        );
      }

      debugPrint('[ProviderConfig] Saved provider: $name ($id)');
    } catch (e) {
      debugPrint('[ProviderConfig] Error saving provider: $e');
      rethrow;
    }
  }

  /// Set provider configuration (legacy method for backward compatibility)
  Future<void> setConfiguration(ProviderConfiguration config) async {
    // Convert old ProviderConfiguration to new format and save
    await saveProvider(
      name: config.providerId,
      type: _stringToProviderType(config.providerType),
      url: config.baseUrl,
      isLocal: true, // Assume local for legacy configs
    );
  }

  /// Get provider configuration (legacy method for backward compatibility)
  ProviderConfiguration? getConfiguration(String providerId) {
    // Return null - this is a legacy method
    // Use getProviderById() instead which returns Future
    return null;
  }

  /// Get provider by ID
  Future<ProviderInfo?> getProviderById(String id) async {
    try {
      final db = serviceLocator<LocalBrain>();

      final results = await db.customSelect(
        'SELECT id, name, type, url, is_local, version FROM llm_providers WHERE id = ?',
        variables: [Variable(id)],
      ).get();

      if (results.isEmpty) return null;

      final row = results.first;
      return ProviderInfo(
        id: row.read<String>('id'),
        name: row.read<String>('name'),
        type: _stringToProviderType(row.read<String>('type')),
        url: row.read<String>('url'),
        isLocal: row.read<bool>('is_local'),
        isAvailable: true,
        version: row.read<String?>('version'),
      );
    } catch (e) {
      debugPrint('[ProviderConfig] Error getting provider by ID: $e');
      return null;
    }
  }

  /// Set preferred provider (alias for setDefaultProvider)
  Future<void> setPreferredProvider(String providerId) async {
    try {
      final db = serviceLocator<LocalBrain>();

      // First, verify provider exists
      final results = await db.customSelect(
        'SELECT id FROM llm_providers WHERE id = ?',
        variables: [Variable(providerId)],
      ).get();

      if (results.isEmpty) {
        debugPrint('[ProviderConfig] Provider not found: $providerId');
        return;
      }

      // Unset all defaults, then set the new one
      await db.customUpdate(
        'UPDATE llm_providers SET is_default = 0',
      );
      await db.customUpdate(
        'UPDATE llm_providers SET is_default = 1 WHERE id = ?',
        variables: [Variable(providerId)],
      );

      debugPrint('[ProviderConfig] Set preferred provider: $providerId');
    } catch (e) {
      debugPrint('[ProviderConfig] Error setting preferred provider: $e');
      rethrow;
    }
  }

  /// Get preferred provider ID (returns default provider)
  Future<String?> getPreferredProviderId() async {
    try {
      final db = serviceLocator<LocalBrain>();

      final results = await db
          .customSelect(
            'SELECT id FROM llm_providers WHERE is_default = 1 LIMIT 1',
          )
          .get();

      if (results.isEmpty) {
        // If no default, return the first provider
        final allResults = await db
            .customSelect(
              'SELECT id FROM llm_providers LIMIT 1',
            )
            .get();
        return allResults.isNotEmpty
            ? allResults.first.read<String>('id')
            : null;
      }

      return results.first.read<String>('id');
    } catch (e) {
      debugPrint('[ProviderConfig] Error getting preferred provider: $e');
      return null;
    }
  }

  /// Get preferred provider ID (sync version for legacy compatibility)
  String? get preferredProviderId {
    // Return null - use the async version
    return null;
  }

  /// Remove provider configuration
  Future<void> removeConfiguration(String providerId) async {
    try {
      final db = serviceLocator<LocalBrain>();
      await db.customUpdate(
        'DELETE FROM llm_providers WHERE id = ?',
        variables: [Variable(providerId)],
      );
      debugPrint('[ProviderConfig] Removed provider: $providerId');
    } catch (e) {
      debugPrint('[ProviderConfig] Error removing provider: $e');
      rethrow;
    }
  }

  /// Clear all provider configurations (for testing/reset)
  Future<void> clearAllProviders() async {
    try {
      final db = serviceLocator<LocalBrain>();
      await db.customUpdate('DELETE FROM llm_providers');
      debugPrint('[ProviderConfig] Cleared all providers');
    } catch (e) {
      debugPrint('[ProviderConfig] Error clearing providers: $e');
      rethrow;
    }
  }

  /// Clear all user data including providers, passwords, and setup status
  Future<void> clearAllUserData() async {
    try {
      final secureStorage = const FlutterSecureStorage();

      // Clear all providers from database
      await clearAllProviders();

      // Clear gateway password
      await secureStorage.delete(key: 'openclaw_gateway_password');
      debugPrint(
          '[ProviderConfig] Cleared gateway password from secure storage');

      // Clear setup status (if we have access to it)
      try {
        await secureStorage.delete(key: 'cloudtolocalllm_setup_status');
        await secureStorage.delete(key: 'cloudtolocalllm_setup_progress');
        debugPrint('[ProviderConfig] Cleared setup status');
      } catch (e) {
        debugPrint('[ProviderConfig] Note: Could not clear setup status: $e');
      }

      debugPrint('[ProviderConfig] Cleared all user data successfully');
    } catch (e) {
      debugPrint('[ProviderConfig] Error clearing user data: $e');
      rethrow;
    }
  }

  /// Update a provider
  Future<void> updateProvider(ProviderInfo provider) async {
    await saveProvider(
      name: provider.name,
      type: provider.type,
      url: provider.url,
      isLocal: provider.isLocal,
      version: provider.version,
    );
  }

  // Helper methods

  ProviderType _stringToProviderType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'openclaw':
        return ProviderType.openclaw;
      case 'lmstudio':
        return ProviderType.lmStudio;
      case 'ollama':
        return ProviderType.ollama;
      case 'openai_compatible':
        return ProviderType.openAICompatible;
      default:
        return ProviderType.custom;
    }
  }
}
