import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

/// Service to detect if desktop clients are connected to the web interface
///
/// On web platform, this service monitors active bridge connections
/// to determine if any desktop clients are currently connected.
///
/// PRIVACY POLICY:
/// - Only checks connection status, no personal data transmitted
/// - Uses authenticated API calls with JWT tokens only
/// - No conversation or user data involved in detection
class DesktopClientDetectionService extends ChangeNotifier {
  final AuthService _authService;

  // Connection state
  bool _hasConnectedClients = false;
  int _connectedClientCount = 0;
  List<DesktopClientInfo> _connectedClients = [];
  String? _error;
  DateTime? _lastCheck;

  // Monitoring
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  // HTTP client
  final Dio _dio = Dio();

  DesktopClientDetectionService({required AuthService authService})
      : _authService = authService {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
  }

  // Getters
  bool get hasConnectedClients => _hasConnectedClients;
  int get connectedClientCount => _connectedClientCount;
  List<DesktopClientInfo> get connectedClients =>
      List.unmodifiable(_connectedClients);
  String? get error => _error;
  DateTime? get lastCheck => _lastCheck;
  bool get isMonitoring => _isMonitoring;

  /// Initialize the service and start monitoring (web platform only)
  Future<void> initialize() async {
    if (!kIsWeb) {
      debugPrint(' [DesktopClientDetection] Skipping on non-web platform');
      return;
    }

    debugPrint(
      ' [DesktopClientDetection] Initializing desktop client detection...',
    );

    // Only check if user is authenticated
    if (_authService.isAuthenticated.value) {
      // Perform initial check
      await checkConnectedClients();
      // Start periodic monitoring
      startMonitoring();
    } else {
      debugPrint(
        ' [DesktopClientDetection] User not authenticated, skipping initial check',
      );
      // Listen for auth state changes to start monitoring when authenticated
      _authService.addListener(_onAuthStateChanged);
    }

    debugPrint(
      ' [DesktopClientDetection] Desktop client detection initialized',
    );
  }

  /// Start monitoring for connected desktop clients
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (!kIsWeb || _isMonitoring) return;

    debugPrint(' [DesktopClientDetection] Starting client monitoring...');

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(interval, (_) => checkConnectedClients());

    notifyListeners();
  }

  /// Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    debugPrint(' [DesktopClientDetection] Stopping client monitoring...');

    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;

    notifyListeners();
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    if (_authService.isAuthenticated.value && !_isMonitoring) {
      debugPrint(
        ' [DesktopClientDetection] User authenticated, starting monitoring',
      );
      checkConnectedClients();
      startMonitoring();
      // Remove listener once monitoring starts
      _authService.removeListener(_onAuthStateChanged);
    }
  }

  /// Check for connected desktop clients
  Future<void> checkConnectedClients() async {
    if (!kIsWeb) return;

    try {
      final accessToken = await _authService.getValidatedAccessToken();
      if (accessToken == null) {
        _updateState(
          hasConnectedClients: false,
          connectedClientCount: 0,
          connectedClients: [],
          error: 'No authentication token available',
        );
        return;
      }

      // First, register the desktop client
      final registerResponse = await _dio.post(
        AppConfig.bridgeRegisterUrl,
        data: {
          'clientId': 'desktop-web',
          'platform': 'web',
          'version': AppConfig.appVersion,
        },
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );

      if (registerResponse.statusCode != 200) {
        throw Exception(
            'Failed to register desktop client: ${registerResponse.statusMessage}');
      }

      // Then check connected clients using the registered bridge
      final bridgeId = registerResponse.data['bridgeId'];
      final statusResponse = await _dio.get(
        '${AppConfig.bridgePollingUrl}/$bridgeId/status',
        options: Options(headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        }),
      );

      if (statusResponse.statusCode == 200) {
        final data = statusResponse.data;
        final bridges = data['bridges'] as List<dynamic>? ?? [];

        final clientInfos = bridges
            .map((bridge) => DesktopClientInfo.fromJson(bridge))
            .toList();

        _updateState(
          hasConnectedClients: clientInfos.isNotEmpty,
          connectedClientCount: clientInfos.length,
          connectedClients: clientInfos,
          error: null,
        );

        debugPrint(
          ' [DesktopClientDetection] Found ${clientInfos.length} connected clients',
        );
      } else {
        throw Exception(
            'HTTP ${statusResponse.statusCode}: ${statusResponse.data}');
      }
    } catch (e) {
      debugPrint(' [DesktopClientDetection] Error checking clients: $e');
      _updateState(
        hasConnectedClients: false,
        connectedClientCount: 0,
        connectedClients: [],
        error: e.toString(),
      );
    }
  }

  /// Update internal state and notify listeners
  void _updateState({
    required bool hasConnectedClients,
    required int connectedClientCount,
    required List<DesktopClientInfo> connectedClients,
    String? error,
  }) {
    final hasChanged = _hasConnectedClients != hasConnectedClients ||
        _connectedClientCount != connectedClientCount ||
        _error != error;

    _hasConnectedClients = hasConnectedClients;
    _connectedClientCount = connectedClientCount;
    _connectedClients = connectedClients;
    _error = error;
    _lastCheck = DateTime.now();

    if (hasChanged) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _dio.close();
    // Remove auth listener if still attached
    try {
      _authService.removeListener(_onAuthStateChanged);
    } catch (e) {
      // Ignore if listener wasn't attached
    }
    super.dispose();
  }
}

/// Information about a connected desktop client
class DesktopClientInfo {
  final String bridgeId;
  final DateTime connectedAt;
  final DateTime lastPing;

  const DesktopClientInfo({
    required this.bridgeId,
    required this.connectedAt,
    required this.lastPing,
  });

  factory DesktopClientInfo.fromJson(Map<String, dynamic> json) {
    return DesktopClientInfo(
      bridgeId: json['bridgeId'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastPing: DateTime.parse(json['lastPing'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bridgeId': bridgeId,
      'connectedAt': connectedAt.toIso8601String(),
      'lastPing': lastPing.toIso8601String(),
    };
  }

  /// Get a user-friendly display name for the client
  String get displayName {
    return 'Desktop Client';
  }

  /// Check if the client is considered active (pinged recently)
  bool get isActive {
    final now = DateTime.now();
    final timeSinceLastPing = now.difference(lastPing);
    return timeSinceLastPing.inMinutes <
        2; // Consider active if pinged within 2 minutes
  }
}
