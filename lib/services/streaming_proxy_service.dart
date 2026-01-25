import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Represents a queued request for parallel processing
class _QueuedRequest {
  final String method;
  final String path;
  final Map<String, dynamic>? data;
  final Completer<Map<String, dynamic>> completer;
  final DateTime queuedAt;

  _QueuedRequest(this.method, this.path, this.data, this.completer)
      : queuedAt = DateTime.now();
}

/// Represents an active request being processed
class _ActiveRequest {
  final String id;
  final DateTime startedAt;
  final Completer<Map<String, dynamic>> completer;

  _ActiveRequest(this.id, this.completer) : startedAt = DateTime.now();

  Duration get duration => DateTime.now().difference(startedAt);
}

/// Service for managing streaming proxy connections
/// Handles proxy lifecycle, status monitoring, and connection management
/// Features connection multiplexing and parallel request processing
class StreamingProxyService extends ChangeNotifier {
  final String _baseUrl;
  final Duration _timeout;
  final AuthService? _authService;
  final Dio _dio = Dio();

  // Connection multiplexing and parallel processing
  final Queue<_QueuedRequest> _requestQueue = Queue<_QueuedRequest>();
  final Set<_ActiveRequest> _activeRequests = {};
  static const int _maxConcurrentRequests = 5;
  Timer? _queueProcessor;

  bool _isProxyRunning = false;
  String? _proxyId;
  DateTime? _proxyCreatedAt;
  String? _error;
  bool _isLoading = false;

  // Performance metrics
  int _totalRequests = 0;
  Duration _averageResponseTime = Duration.zero;

  StreamingProxyService({
    String? baseUrl,
    Duration? timeout,
    AuthService? authService,
  })  : _baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
        _timeout = timeout ?? AppConfig.apiTimeout,
        _authService = authService {
    _setupDio();
    if (kDebugMode) {
      debugPrint('[StreamingProxy] Service initialized');
      debugPrint('[StreamingProxy] Base URL: $_baseUrl');
    }
  }

  void _setupDio() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = _timeout;
    _dio.options.receiveTimeout = _timeout;

    // Start queue processor
    _startQueueProcessor();
  }

  void _startQueueProcessor() {
    _queueProcessor = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _processQueue();
    });
  }

  void _processQueue() {
    // Process queued requests up to the concurrency limit
    while (_activeRequests.length < _maxConcurrentRequests &&
        _requestQueue.isNotEmpty) {
      final request = _requestQueue.removeFirst();
      _executeRequest(request);
    }
  }

  Future<void> _executeRequest(_QueuedRequest request) async {
    final requestId =
        '${request.method}_${request.path}_${DateTime.now().millisecondsSinceEpoch}';
    final activeRequest = _ActiveRequest(requestId, request.completer);
    _activeRequests.add(activeRequest);

    try {
      final startTime = DateTime.now();
      final headers = await _getHeaders();

      Response response;
      switch (request.method) {
        case 'GET':
          response = await _dio.get(
            request.path,
            options: Options(headers: headers),
          );
          break;
        case 'POST':
          response = await _dio.post(
            request.path,
            data: request.data,
            options: Options(headers: headers),
          );
          break;
        case 'PUT':
          response = await _dio.put(
            request.path,
            data: request.data,
            options: Options(headers: headers),
          );
          break;
        case 'DELETE':
          response = await _dio.delete(
            request.path,
            options: Options(headers: headers),
          );
          break;
        default:
          throw UnsupportedError('HTTP method ${request.method} not supported');
      }

      final responseTime = DateTime.now().difference(startTime);
      _updateMetrics(true, responseTime);

      request.completer.complete(response.data);
    } catch (e) {
      _updateMetrics(false, activeRequest.duration);
      request.completer.completeError(e);
    } finally {
      _activeRequests.remove(activeRequest);
    }
  }

  void _updateMetrics(bool success, Duration responseTime) {
    _totalRequests++;

    // Update rolling average response time
    final totalResponseTime =
        _averageResponseTime * (_totalRequests - 1) + responseTime;
    _averageResponseTime = totalResponseTime ~/ _totalRequests;
  }

  // Getters
  bool get isProxyRunning => _isProxyRunning;
  String? get proxyId => _proxyId;
  DateTime? get proxyCreatedAt => _proxyCreatedAt;
  String? get error => _error;
  bool get isLoading => _isLoading;

  /// Get HTTP headers with authentication
  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_authService != null) {
      final accessToken = await _authService.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }

    return headers;
  }

  /// Start streaming proxy for current user with connection multiplexing
  Future<bool> startProxy() async {
    final completer = Completer<Map<String, dynamic>>();
    final request = _QueuedRequest('POST', '/proxy/start', null, completer);

    _requestQueue.add(request);

    try {
      final response = await completer.future;

      if (response['success'] == true) {
        _proxyId = response['proxy']['proxyId'];
        _proxyCreatedAt = DateTime.parse(response['proxy']['createdAt']);
        _isProxyRunning = true;

        if (kDebugMode) {
          debugPrint('[StreamingProxy] Proxy started: $_proxyId');
        }

        notifyListeners();
        return true;
      } else {
        _setError('Failed to start proxy: ${response['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to start proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Start error: $e');
      }
      return false;
    }
  }

  /// Stop streaming proxy for current user
  Future<bool> stopProxy() async {
    try {
      _setLoading(true);
      _clearError();

      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stopping proxy...');
      }

      final headers = await _getHeaders();
      final response = await _dio.post(
        '/proxy/stop',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          _proxyId = null;
          _proxyCreatedAt = null;
          _isProxyRunning = false;

          if (kDebugMode) {
            debugPrint('[StreamingProxy] Proxy stopped successfully');
          }

          notifyListeners();
          return true;
        } else {
          _setError('Failed to stop proxy: ${data['message']}');
          return false;
        }
      } else {
        final errorData = response.data;
        _setError('Failed to stop proxy: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to stop proxy: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Stop error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Get streaming proxy status
  Future<bool> checkProxyStatus() async {
    try {
      _setLoading(true);
      _clearError();

      final headers = await _getHeaders();
      final response = await _dio.get(
        '/proxy/status',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        _isProxyRunning = data['status'] == 'running';

        if (_isProxyRunning) {
          _proxyId = data['proxyId'];
          if (data['createdAt'] != null) {
            _proxyCreatedAt = DateTime.parse(data['createdAt']);
          }
        } else {
          _proxyId = null;
          _proxyCreatedAt = null;
        }

        if (kDebugMode) {
          debugPrint('[StreamingProxy] Status: ${data['status']}');
        }

        notifyListeners();
        return _isProxyRunning;
      } else {
        final errorData = response.data;
        _setError('Failed to check proxy status: ${errorData['message']}');
        return false;
      }
    } catch (e) {
      _setError('Failed to check proxy status: $e');
      if (kDebugMode) {
        debugPrint('[StreamingProxy] Status check error: $e');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Ensure proxy is running (start if not running)
  Future<bool> ensureProxyRunning() async {
    // First check current status
    await checkProxyStatus();

    // Start proxy if not running
    if (!_isProxyRunning) {
      return await startProxy();
    }

    return true;
  }

  /// Get proxy uptime
  Duration? get proxyUptime {
    if (_proxyCreatedAt == null) return null;
    return DateTime.now().difference(_proxyCreatedAt!);
  }

  /// Get formatted proxy uptime
  String get formattedUptime {
    final uptime = proxyUptime;
    if (uptime == null) return 'N/A';

    final hours = uptime.inHours;
    final minutes = uptime.inMinutes % 60;
    final seconds = uptime.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
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
    notifyListeners();
  }

  @override
  void dispose() {
    _queueProcessor?.cancel();
    _requestQueue.clear();
    _activeRequests.clear();
    super.dispose();
  }
}
