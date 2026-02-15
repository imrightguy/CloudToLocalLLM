import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'conversation_storage_service.dart';
import 'auth_logger.dart';

// Conditional import for web interop
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

/// Administrative data flush service for CloudToLocalLLM
///
/// Provides secure administrative functionality to clear all user data
/// when needed for maintenance, testing, or emergency scenarios.
///
/// Features:
/// - Multi-step confirmation process
/// - Comprehensive data clearing operations
/// - Audit trail and operation tracking
/// - Integration with existing authentication system
class AdminDataFlushService extends ChangeNotifier {
  final Dio _dio;
  final AuthService _authService;
  final FlutterSecureStorage _secureStorage;
  final ConversationStorageService? _conversationStorage;

  // Operation state
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _lastOperationResult;
  List<Map<String, dynamic>> _operationHistory = [];

  // Confirmation state
  String? _confirmationToken;
  DateTime? _tokenExpiresAt;

  AdminDataFlushService({
    required AuthService authService,
    Dio? dio,
    FlutterSecureStorage? secureStorage,
    ConversationStorageService? conversationStorage,
  })  : _authService = authService,
        _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _conversationStorage = conversationStorage {
    _setupDio();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, dynamic>? get lastOperationResult => _lastOperationResult;
  List<Map<String, dynamic>> get operationHistory =>
      List.unmodifiable(_operationHistory);
  bool get hasValidConfirmationToken =>
      _confirmationToken != null &&
      _tokenExpiresAt != null &&
      DateTime.now().isBefore(_tokenExpiresAt!);

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.cloudGatewayUrl;
    _dio.options.connectTimeout = AppConfig.gatewayTimeout;
    _dio.options.receiveTimeout = AppConfig.gatewayTimeout;

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getValidatedAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint(' [DataFlush] API Error: ${error.message}');
          handler.next(error);
        },
      ),
    );
  }

  /// Clear any previous error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Get system statistics for admin dashboard
  Future<Map<String, dynamic>?> getSystemStatistics() async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(' [DataFlush] Fetching system statistics');

      final response = await _dio.get('/admin/system/stats');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint(' [DataFlush] System statistics retrieved successfully');
        return response.data['data'];
      } else {
        throw Exception('Failed to retrieve system statistics');
      }
    } catch (e) {
      _setError('Failed to get system statistics: ${e.toString()}');
      debugPrint(' [DataFlush] Error getting system statistics: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Prepare data flush operation and get confirmation token
  Future<bool> prepareDataFlush({
    String? targetUserId,
    String scope = 'FULL_FLUSH',
  }) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(' [DataFlush] Preparing data flush operation');
      debugPrint(' [DataFlush] Target: ${targetUserId ?? 'ALL_USERS'}');
      debugPrint(' [DataFlush] Scope: $scope');

      final response = await _dio.post(
        '/admin/flush/prepare',
        data: {'targetUserId': targetUserId, 'scope': scope},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _confirmationToken = response.data['confirmationToken'];
        _tokenExpiresAt = DateTime.parse(response.data['expiresAt']);

        debugPrint(' [DataFlush] Flush operation prepared successfully');
        debugPrint(' [DataFlush] Token expires at: $_tokenExpiresAt');

        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to prepare flush operation');
      }
    } catch (e) {
      _setError('Failed to prepare data flush: ${e.toString()}');
      debugPrint(' [DataFlush] Error preparing data flush: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Execute data flush operation with confirmation
  Future<bool> executeDataFlush({
    String? targetUserId,
    Map<String, bool> options = const {},
  }) async {
    if (!hasValidConfirmationToken) {
      _setError(
        'No valid confirmation token. Please prepare the operation first.',
      );
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      debugPrint(' [DataFlush] CRITICAL: Executing data flush operation');
      debugPrint(' [DataFlush] Target: ${targetUserId ?? 'ALL_USERS'}');
      debugPrint(' [DataFlush] Options: $options');

      final response = await _dio.post(
        '/admin/flush/execute',
        data: {
          'confirmationToken': _confirmationToken,
          'targetUserId': targetUserId,
          'options': options,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _lastOperationResult = response.data;

        // Clear confirmation token after use
        _confirmationToken = null;
        _tokenExpiresAt = null;

        // Add to operation history
        _operationHistory.insert(0, {
          'operationId': response.data['operationId'],
          'timestamp': DateTime.now().toIso8601String(),
          'targetUserId': targetUserId ?? 'ALL_USERS',
          'results': response.data['results'],
          'duration': response.data['duration'],
        });

        // Keep only last 20 operations in memory
        if (_operationHistory.length > 20) {
          _operationHistory = _operationHistory.take(20).toList();
        }

        debugPrint(' [DataFlush] CRITICAL: Data flush executed successfully');
        debugPrint(
          ' [DataFlush] Operation ID: ${response.data['operationId']}',
        );

        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to execute flush operation');
      }
    } catch (e) {
      _setError('Failed to execute data flush: ${e.toString()}');
      debugPrint(' [DataFlush] CRITICAL: Error executing data flush: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get flush operation history
  Future<bool> loadFlushHistory({int limit = 50}) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(' [DataFlush] Loading flush operation history');

      final response = await _dio.get(
        '/admin/flush/history',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _operationHistory = List<Map<String, dynamic>>.from(
          response.data['data'],
        );

        debugPrint(
          ' [DataFlush] Loaded ${_operationHistory.length} operations',
        );

        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to load flush history');
      }
    } catch (e) {
      _setError('Failed to load flush history: ${e.toString()}');
      debugPrint(' [DataFlush] Error loading flush history: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Emergency container cleanup
  Future<bool> emergencyContainerCleanup() async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(' [DataFlush] Executing emergency container cleanup');

      final response = await _dio.post('/admin/containers/cleanup');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _lastOperationResult = response.data;

        debugPrint(' [DataFlush] Emergency cleanup completed');
        debugPrint(' [DataFlush] Results: ${response.data['results']}');

        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to execute emergency cleanup');
      }
    } catch (e) {
      _setError('Failed to execute emergency cleanup: ${e.toString()}');
      debugPrint(' [DataFlush] Error in emergency cleanup: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Check if current user has admin privileges
  Future<bool> checkAdminPrivileges() async {
    try {
      final response = await _dio.get('/admin/health');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint(' [DataFlush] Admin privilege check failed: $e');
      return false;
    }
  }

  /// Clear all local data (client-side cleanup)
  /// Comprehensive data clearing including conversations, auth tokens, settings, and cache
  Future<Map<String, dynamic>> clearLocalData() async {
    final results = <String, dynamic>{
      'secureStorage': false,
      'conversations': false,
      'webLocalStorage': false,
      'authLogs': false,
      'serviceCache': false,
    };

    try {
      debugPrint(' [DataFlush] Starting comprehensive local data clearing');

      // 1. Clear secure storage (auth tokens, settings, etc.)
      try {
        await _secureStorage.deleteAll();
        results['secureStorage'] = true;
        debugPrint(' [DataFlush] Secure storage cleared');
      } catch (e) {
        debugPrint(' [DataFlush] Error clearing secure storage: $e');
      }

      // 2. Clear conversation database
      if (_conversationStorage != null) {
        try {
          await _conversationStorage.clearAllConversations();
          results['conversations'] = true;
          debugPrint(' [DataFlush] Conversation database cleared');
        } catch (e) {
          debugPrint(' [DataFlush] Error clearing conversations: $e');
        }
      }

      // 3. Clear web localStorage (tokens, auth logs, etc.)
      if (kIsWeb) {
        try {
          _clearWebLocalStorage();
          results['webLocalStorage'] = true;
          debugPrint(' [DataFlush] Web localStorage cleared');
        } catch (e) {
          debugPrint(' [DataFlush] Error clearing web localStorage: $e');
        }
      }

      // 4. Clear authentication logs
      try {
        AuthLogger.clearLogs();
        results['authLogs'] = true;
        debugPrint(' [DataFlush] Authentication logs cleared');
      } catch (e) {
        debugPrint(' [DataFlush] Error clearing auth logs: $e');
      }

      // 5. Clear service cache and state
      try {
        _lastOperationResult = null;
        _operationHistory.clear();
        _confirmationToken = null;
        _tokenExpiresAt = null;
        results['serviceCache'] = true;
        debugPrint(' [DataFlush] Service cache cleared');
      } catch (e) {
        debugPrint(' [DataFlush] Error clearing service cache: $e');
      }

      final successCount = results.values.where((v) => v == true).length;
      debugPrint(
        ' [DataFlush] Local data clearing completed: $successCount/${results.length} operations successful',
      );

      notifyListeners();
      return results;
    } catch (e) {
      debugPrint(' [DataFlush] Critical error during local data clearing: $e');
      _setError('Failed to clear local data: ${e.toString()}');
      return results;
    }
  }

  /// Clear web localStorage data (web platform only)
  void _clearWebLocalStorage() {
    if (!kIsWeb) return;

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

      debugPrint(
        ' [DataFlush] Removed ${keysToRemove.length} localStorage keys',
      );
    } catch (e) {
      debugPrint(' [DataFlush] Error clearing web localStorage: $e');
      rethrow;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
