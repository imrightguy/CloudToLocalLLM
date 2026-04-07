import 'package:cloudtolocalllm/config/app_config.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/container_creation_result.dart';
import 'auth_service.dart';

/// Service for managing user-specific streaming proxy containers
///
/// This service interfaces with the existing StreamingProxyManager on the API backend
/// to create, manage, and monitor isolated streaming proxy containers for users.
/// Each user gets their own ephemeral container for secure LLM communication.
class UserContainerService extends ChangeNotifier {
  final AuthService _authService;
  final String _baseUrl;
  final Dio _dio = Dio();

  // Container state tracking
  String? _currentContainerId;
  String? _currentProxyId;
  ContainerCreationResult? _lastCreationResult;
  bool _isCreatingContainer = false;
  bool _isCheckingStatus = false;
  DateTime? _lastStatusCheck;

  UserContainerService({required AuthService authService, String? baseUrl})
      : _authService = authService,
        _baseUrl = baseUrl ?? _getDefaultBaseUrl() {
    _setupDio();
    debugPrint(
      '� [UserContainer] Service initialized with baseUrl: $_baseUrl',
    );
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  // Getters
  String? get currentContainerId => _currentContainerId;
  String? get currentProxyId => _currentProxyId;
  ContainerCreationResult? get lastCreationResult => _lastCreationResult;
  bool get isCreatingContainer => _isCreatingContainer;
  bool get isCheckingStatus => _isCheckingStatus;
  DateTime? get lastStatusCheck => _lastStatusCheck;
  bool get hasActiveContainer =>
      _currentContainerId != null && _currentProxyId != null;

  /// Get the default base URL based on environment
  static String _getDefaultBaseUrl() {
    if (kDebugMode) {
      return AppConfig.adminServerUrl;
    } else {
      return AppConfig.apiBaseUrl;
    }
  }

  /// Create a new streaming proxy container for the current user
  ///
  /// This method calls the API backend's streaming proxy provisioning endpoint
  /// to create an isolated container for the authenticated user.
  Future<ContainerCreationResult> createUserContainer({
    bool testMode = false,
  }) async {
    if (!_authService.isAuthenticated.value) {
      final result = ContainerCreationResult.failure(
        errorMessage: 'User not authenticated',
        errorCode: 'AUTH_REQUIRED',
      );
      _lastCreationResult = result;
      return result;
    }

    _isCreatingContainer = true;
    notifyListeners();

    try {
      debugPrint(
        '� [UserContainer] Creating container (testMode: $testMode)...',
      );

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get valid access token');
      }

      final response = await _dio.post(
        '/streaming-proxy/provision',
        data: {'testMode': testMode},
        options: Options(headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        }),
      );

      debugPrint(
        '� [UserContainer] API response status: ${response.statusCode}',
      );
      debugPrint('� [UserContainer] API response data: ${response.data}');

      if (response.statusCode == 200) {
        final responseData = response.data as Map<String, dynamic>;

        if (responseData['success'] == true) {
          final proxyData = responseData['proxy'] as Map<String, dynamic>;

          _currentContainerId = proxyData['containerId'] as String?;
          _currentProxyId = proxyData['proxyId'] as String;

          final result = ContainerCreationResult.success(
            containerId: _currentContainerId ?? 'unknown',
            proxyId: _currentProxyId!,
            containerInfo: {
              'status': proxyData['status'],
              'createdAt': proxyData['createdAt'],
              'testMode': responseData['testMode'] ?? false,
            },
          );

          _lastCreationResult = result;
          debugPrint(
            '� [UserContainer] Container created successfully: $_currentProxyId',
          );

          return result;
        } else {
          throw Exception(
            responseData['message'] ?? 'Container creation failed',
          );
        }
      } else {
        final errorData = jsonDecode(response.data) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('� [UserContainer] Container creation failed: $e');

      final result = ContainerCreationResult.failure(
        errorMessage: e.toString(),
        errorCode: 'CREATION_FAILED',
      );

      _lastCreationResult = result;
      return result;
    } finally {
      _isCreatingContainer = false;
      notifyListeners();
    }
  }

  /// Check the status and health of the current user's container
  ///
  /// This method queries the API backend to get the current status of the
  /// user's streaming proxy container, including health information.
  Future<Map<String, dynamic>> checkContainerStatus() async {
    if (!_authService.isAuthenticated.value) {
      return {'status': 'error', 'error': 'User not authenticated'};
    }

    _isCheckingStatus = true;
    _lastStatusCheck = DateTime.now();
    notifyListeners();

    try {
      debugPrint('� [UserContainer] Checking container status...');

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get valid access token');
      }

      final response = await _dio.get(
        '/proxy/status',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint(
        '� [UserContainer] Status check response: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final statusData = response.data as Map<String, dynamic>;
        debugPrint(
          '� [UserContainer] Container status: ${statusData['status']}',
        );

        // Update local state if we have container info
        if (statusData['proxyId'] != null) {
          _currentProxyId = statusData['proxyId'] as String;
        }

        return statusData;
      } else {
        final errorData = jsonDecode(response.data) as Map<String, dynamic>;
        throw Exception(errorData['message'] ?? 'HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('� [UserContainer] Status check failed: $e');
      return {'status': 'error', 'error': e.toString()};
    } finally {
      _isCheckingStatus = false;
      notifyListeners();
    }
  }

  /// Validate that the container is healthy and ready for use
  ///
  /// This method performs comprehensive health checks on the container
  /// to ensure it's ready to handle streaming requests.
  Future<bool> validateContainerHealth() async {
    try {
      debugPrint('� [UserContainer] Validating container health...');

      final status = await checkContainerStatus();

      if (status['status'] == 'running') {
        final health = status['health'] as String?;
        final isHealthy =
            health == null || health == 'healthy' || health == 'unknown';

        debugPrint(
          '� [UserContainer] Container health validation: $isHealthy (health: $health)',
        );
        return isHealthy;
      }

      debugPrint(
        '� [UserContainer] Container not running: ${status['status']}',
      );
      return false;
    } catch (e) {
      debugPrint('� [UserContainer] Health validation failed: $e');
      return false;
    }
  }

  /// Stop and remove the current user's container
  ///
  /// This method terminates the user's streaming proxy container
  /// and cleans up associated resources.
  Future<bool> stopUserContainer() async {
    if (!_authService.isAuthenticated.value) {
      debugPrint(
        '� [UserContainer] Cannot stop container: user not authenticated',
      );
      return false;
    }

    try {
      debugPrint('� [UserContainer] Stopping container...');

      final token = await _authService.getValidatedAccessToken();
      if (token == null) {
        throw Exception('Failed to get valid access token');
      }

      final response = await _dio.post(
        '/proxy/stop',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      debugPrint('� [UserContainer] Stop response: ${response.statusCode}');

      if (response.statusCode == 200) {
        _currentContainerId = null;
        _currentProxyId = null;
        notifyListeners();

        debugPrint('� [UserContainer] Container stopped successfully');
        return true;
      } else {
        final errorData = jsonDecode(response.data) as Map<String, dynamic>;
        debugPrint('� [UserContainer] Stop failed: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('� [UserContainer] Stop container failed: $e');
      return false;
    }
  }

  /// Get comprehensive container information
  ///
  /// Returns detailed information about the current container state,
  /// including creation result, status, and health information.
  Future<Map<String, dynamic>> getContainerInfo() async {
    final status = await checkContainerStatus();

    return {
      'hasActiveContainer': hasActiveContainer,
      'currentContainerId': _currentContainerId,
      'currentProxyId': _currentProxyId,
      'isCreatingContainer': _isCreatingContainer,
      'isCheckingStatus': _isCheckingStatus,
      'lastStatusCheck': _lastStatusCheck?.toIso8601String(),
      'lastCreationResult': _lastCreationResult?.toJson(),
      'currentStatus': status,
    };
  }

  /// Reset the container state (for testing or cleanup)
  void resetContainerState() {
    _currentContainerId = null;
    _currentProxyId = null;
    _lastCreationResult = null;
    _isCreatingContainer = false;
    _isCheckingStatus = false;
    _lastStatusCheck = null;

    debugPrint('� [UserContainer] Container state reset');
    notifyListeners();
  }

  /// Check if container creation is supported in the current environment
  bool get isContainerCreationSupported {
    // Container creation is only supported on web platform
    // Desktop clients handle their own local connections
    return kIsWeb;
  }

  @override
  void dispose() {
    debugPrint('� [UserContainer] Service disposed');
    super.dispose();
  }
}
