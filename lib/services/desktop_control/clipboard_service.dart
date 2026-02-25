import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/utils/logger.dart';

/// Service for managing clipboard operations and history
/// Supports desktop platforms with full functionality,
/// web platform has limited support (no monitoring)
class ClipboardService with ChangeNotifier {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  late final LocalBrain _database;
  bool _isInitialized = false;
  bool _isMonitoring = false;
  String? _lastContent;
  Timer? _monitoringTimer;

  bool get isInitialized => _isInitialized;
  bool get isMonitoring => _isMonitoring;
  String? get lastContent => _lastContent;

  /// Initialize clipboard service with database connection
  Future<void> initialize(LocalBrain database) async {
    if (_isInitialized) return;

    try {
      _database = database;
      _isInitialized = true;
      appLogger.info('[Clipboard] Clipboard service initialized');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to initialize', error: e);
    }
  }

  /// Copy text to clipboard
  Future<void> copy(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      _lastContent = content;
      notifyListeners();
      appLogger.info('[Clipboard] Copied content to clipboard');

      // Save to history if monitoring is enabled
      if (_isMonitoring) {
        await _addToHistory(content, 'text');
      }
    } catch (e) {
      appLogger.error('[Clipboard] Failed to copy', error: e);
      rethrow;
    }
  }

  /// Get current clipboard content
  Future<String?> getClipboardContent() async {
    try {
      final data = await Clipboard.getData('text/plain');
      _lastContent = data?.text;
      return _lastContent;
    } catch (e) {
      appLogger.error('[Clipboard] Failed to get content', error: e);
      return null;
    }
  }

  /// Start monitoring clipboard changes
  /// Uses polling to detect changes (every 2 seconds)
  /// Not supported on web due to browser security restrictions
  Future<void> startMonitoring() async {
    if (_isMonitoring || kIsWeb) {
      if (kIsWeb) {
        appLogger.warning('[Clipboard] Monitoring not supported on web');
      }
      return;
    }

    try {
      _isMonitoring = true;
      _lastContent = await getClipboardContent();

      // Start polling timer - handle async properly
      _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        unawaited(_checkForChanges());
      });

      notifyListeners();
      appLogger.info('[Clipboard] Started monitoring clipboard');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to start monitoring', error: e);
    }
  }

  /// Stop monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
      notifyListeners();
      appLogger.info('[Clipboard] Stopped monitoring clipboard');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to stop monitoring', error: e);
    }
  }

  /// Search clipboard history
  Future<List<ClipboardHistoryData>> searchHistory(String query) async {
    try {
      final results = await (_database.select(_database.clipboardHistory)
            ..where((tbl) => tbl.content.contains(query))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.timestamp)])
            ..limit(50))
          .get();
      return results;
    } catch (e) {
      appLogger.error('[Clipboard] Failed to search history', error: e);
      return [];
    }
  }

  /// Get clipboard history (recent entries)
  Future<List<ClipboardHistoryData>> getHistory({int limit = 50}) async {
    try {
      final results = await (_database.select(_database.clipboardHistory)
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.timestamp)])
            ..limit(limit))
          .get();
      return results;
    } catch (e) {
      appLogger.error('[Clipboard] Failed to get history', error: e);
      return [];
    }
  }

  /// Clear clipboard history
  Future<void> clearHistory() async {
    try {
      await _database.delete(_database.clipboardHistory).go();
      appLogger.info('[Clipboard] Cleared clipboard history');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to clear history', error: e);
    }
  }

  /// Pin an entry in clipboard history
  Future<void> pinEntry(int id) async {
    try {
      await (_database.update(_database.clipboardHistory)
            ..where((tbl) => tbl.id.equals(id)))
          .write(ClipboardHistoryCompanion(isPinned: const drift.Value(true)));
      appLogger.info('[Clipboard] Pinned clipboard entry $id');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to pin entry', error: e);
    }
  }

  /// Unpin an entry in clipboard history
  Future<void> unpinEntry(int id) async {
    try {
      await (_database.update(_database.clipboardHistory)
            ..where((tbl) => tbl.id.equals(id)))
          .write(ClipboardHistoryCompanion(isPinned: const drift.Value(false)));
      appLogger.info('[Clipboard] Unpinned clipboard entry $id');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to unpin entry', error: e);
    }
  }

  /// Delete a specific entry from history
  Future<void> deleteEntry(int id) async {
    try {
      await (_database.delete(_database.clipboardHistory)
            ..where((tbl) => tbl.id.equals(id)))
          .go();
      appLogger.info('[Clipboard] Deleted clipboard entry $id');
    } catch (e) {
      appLogger.error('[Clipboard] Failed to delete entry', error: e);
    }
  }

  /// Check for clipboard changes (polling-based)
  Future<void> _checkForChanges() async {
    try {
      final currentContent = await getClipboardContent();

      // Check if content changed
      if (_lastContent != null && currentContent != null) {
        if (_lastContent != currentContent) {
          appLogger.info('[Clipboard] Detected clipboard change');
          await _addToHistory(currentContent, 'text');
          _lastContent = currentContent;
          notifyListeners();
        }
      } else if (_lastContent == null && currentContent != null) {
        // First content after null
        await _addToHistory(currentContent, 'text');
        _lastContent = currentContent;
        notifyListeners();
      }
    } catch (e) {
      appLogger.error('[Clipboard] Failed to check for changes', error: e);
    }
  }

  /// Add content to clipboard history
  Future<void> _addToHistory(String content, String contentType) async {
    try {
      // Avoid duplicate entries from same content
      final existing = await (_database.select(_database.clipboardHistory)
            ..where((tbl) => tbl.content.equals(content))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.timestamp)])
            ..limit(1))
          .get();

      if (existing.isNotEmpty) {
        final lastEntry = existing.first;
        final timeDiff = DateTime.now().difference(lastEntry.timestamp);

        // Skip if same content was copied in last 5 seconds
        if (timeDiff.inSeconds < 5) {
          return;
        }
      }

      await _database.insertClipboardEntry(
        ClipboardHistoryCompanion.insert(
          content: content,
          contentType: contentType,
          sourceApp: const drift.Value('CloudToLocalLLM'),
        ),
      );

      // Keep only last 100 entries
      await _cleanupOldEntries();
    } catch (e) {
      appLogger.error('[Clipboard] Failed to add to history', error: e);
    }
  }

  /// Cleanup old clipboard history entries (keep only last 100)
  Future<void> _cleanupOldEntries() async {
    try {
      final entries = await (_database.select(_database.clipboardHistory)
            ..where((tbl) => tbl.isPinned.equals(false))
            ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.timestamp)])
            ..limit(101))
          .get();

      if (entries.length > 100) {
        final toDelete = entries.sublist(100);
        for (final entry in toDelete) {
          await _database.deleteClipboardEntry(entry.id);
        }
        appLogger.info('[Clipboard] Cleaned up ${toDelete.length} old entries');
      }
    } catch (e) {
      appLogger.error('[Clipboard] Failed to cleanup old entries', error: e);
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    super.dispose();
  }
}
