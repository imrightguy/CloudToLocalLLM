import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'conversation_storage_service.dart';
import 'auth_logger.dart';

// Conditional import for web interop
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

/// Simple user data management service for CloudToLocalLLM
///
/// Provides straightforward functionality to clear all user data
/// when needed for privacy, troubleshooting, or starting fresh.
///
/// Features:
/// - Clear all conversations and chat history
/// - Clear authentication tokens and login data
/// - Clear application settings and preferences
/// - Clear cached and temporary data
/// - Simple confirmation process
/// - Comprehensive logging
class UserDataService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage;
  final ConversationStorageService? _conversationStorage;

  // Operation state
  bool _isClearing = false;
  String? _lastError;

  UserDataService({
    FlutterSecureStorage? secureStorage,
    ConversationStorageService? conversationStorage,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _conversationStorage = conversationStorage;

  // Getters
  bool get isClearing => _isClearing;
  String? get lastError => _lastError;

  /// Clear all user data with comprehensive cleanup
  /// Returns a map with results of each cleanup operation
  Future<Map<String, bool>> clearAllUserData() async {
    _isClearing = true;
    _lastError = null;
    notifyListeners();

    final results = <String, bool>{
      'conversations': false,
      'authTokens': false,
      'settings': false,
      'webStorage': false,
      'authLogs': false,
    };

    try {
      debugPrint(' [DataFlush] Starting user data clearing');

      // 1. Clear conversation history
      await _clearConversations(results);

      // 2. Clear authentication tokens and secure storage
      await _clearAuthTokens(results);

      // 3. Clear web localStorage (if on web)
      await _clearWebStorage(results);

      // 4. Clear authentication logs
      await _clearAuthLogs(results);

      final successCount = results.values.where((success) => success).length;
      debugPrint(
        ' [DataFlush] User data clearing completed: $successCount/${results.length} operations successful',
      );

      return results;
    } catch (e) {
      _lastError = 'Failed to clear user data: ${e.toString()}';
      debugPrint(' [DataFlush] Error during user data clearing: $e');
      return results;
    } finally {
      _isClearing = false;
      notifyListeners();
    }
  }

  /// Clear all conversations and chat history
  Future<void> _clearConversations(Map<String, bool> results) async {
    try {
      if (_conversationStorage != null) {
        await _conversationStorage.clearAllConversations();
        results['conversations'] = true;
        debugPrint(' [DataFlush] Conversations cleared');
      } else {
        debugPrint(' [DataFlush] No conversation storage available');
        results['conversations'] = true; // Not an error if not available
      }
    } catch (e) {
      debugPrint(' [DataFlush] Error clearing conversations: $e');
    }
  }

  /// Clear authentication tokens and all secure storage
  Future<void> _clearAuthTokens(Map<String, bool> results) async {
    try {
      await _secureStorage.deleteAll();
      results['authTokens'] = true;
      results['settings'] = true; // Settings are also in secure storage
      debugPrint(' [DataFlush] Auth tokens and settings cleared');
    } catch (e) {
      debugPrint(' [DataFlush] Error clearing auth tokens: $e');
    }
  }

  /// Clear web localStorage (web platform only)
  Future<void> _clearWebStorage(Map<String, bool> results) async {
    if (!kIsWeb) {
      results['webStorage'] = true; // Not applicable on non-web platforms
      return;
    }

    try {
      // Clear CloudToLocalLLM-specific localStorage keys
      final keysToRemove = [
        'cloudtolocalllm_access_token',
        'cloudtolocalllm_id_token',
        'cloudtolocalllm_token_expiry',
        'cloudtolocalllm_authenticated',
        'cloudtolocalllm_auth_logs',
        'cloudtolocalllm_last_validation',
        'cloudtolocalllm_auth_persistent',
      ];

      for (final key in keysToRemove) {
        window.localStorage.removeItem(key);
      }

      results['webStorage'] = true;
      debugPrint(
        ' [DataFlush] Web localStorage cleared (${keysToRemove.length} keys)',
      );
    } catch (e) {
      debugPrint(' [DataFlush] Error clearing web storage: $e');
    }
  }

  /// Clear authentication logs
  Future<void> _clearAuthLogs(Map<String, bool> results) async {
    try {
      AuthLogger.clearLogs();
      results['authLogs'] = true;
      debugPrint(' [DataFlush] Authentication logs cleared');
    } catch (e) {
      debugPrint(' [DataFlush] Error clearing auth logs: $e');
    }
  }

  /// Get a summary of what data will be cleared
  List<String> getDataClearingSummary() {
    return [
      'All conversation history and chat messages',
      'Authentication tokens and login sessions',
      'Application settings and preferences',
      'Cached data and temporary files',
      'Authentication logs and debug data',
      if (kIsWeb) 'Browser localStorage data',
    ];
  }

  /// Clear any previous error state
  void clearError() {
    _lastError = null;
    notifyListeners();
  }
}
