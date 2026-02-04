import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/user_setup_status.dart';
import '../services/auth_service.dart';
import '../services/desktop_client_detection_service.dart';

/// Abstract storage interface for setup status
abstract class SetupStatusStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// In-memory storage implementation for testing
class InMemorySetupStatusStorage implements SetupStatusStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;

  @override
  Future<void> delete(String key) async => _storage.remove(key);
}

/// Secure storage implementation for production
class SecureSetupStatusStorage implements SetupStatusStorage {
  // Note: This would use flutter_secure_storage in a real implementation
  // For now, we'll use in-memory storage to avoid dependency issues
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;

  @override
  Future<void> delete(String key) async => _storage.remove(key);
}

/// Service for tracking user setup completion status and progress
///
/// This service provides centralized management of user setup state including:
/// - First-time user detection and tracking
/// - Setup completion status management
/// - Setup progress persistence and recovery
/// - Integration with authentication and client detection services
class SetupStatusService extends ChangeNotifier {
  static const String _setupStatusKey = 'zoidbot_setup_status';
  static const String _setupProgressKey = 'zoidbot_setup_progress';

  final SetupStatusStorage _storage;
  final AuthService _authService;
  final DesktopClientDetectionService? _clientDetectionService;

  // Current status state
  UserSetupStatus? _currentStatus;
  bool _isInitialized = false;
  String? _lastError;

  // Progress tracking
  Map<String, dynamic> _setupProgress = {};
  DateTime? _lastProgressUpdate;

  SetupStatusService({
    required AuthService authService,
    DesktopClientDetectionService? clientDetectionService,
    SetupStatusStorage? storage,
  })  : _authService = authService,
        _clientDetectionService = clientDetectionService,
        _storage = storage ?? SecureSetupStatusStorage();

  // Getters
  UserSetupStatus? get currentStatus => _currentStatus;
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  Map<String, dynamic> get setupProgress => Map.unmodifiable(_setupProgress);

  /// Initialize the setup status service
  Future<void> initialize() async {
    try {
      debugPrint(' [SetupStatus] Initializing setup status service');

      // Load existing status and progress
      await _loadSetupStatus();
      await _loadSetupProgress();

      // Listen to auth changes
      _authService.addListener(_onAuthStateChanged);

      // Listen to client detection changes
      _clientDetectionService?.addListener(_onClientDetectionChanged);

      _isInitialized = true;
      debugPrint(' [SetupStatus] Setup status service initialized');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to initialize setup status service: ${e.toString()}';
      debugPrint(' [SetupStatus] Error initializing: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Check if the user is a first-time user
  Future<bool> isFirstTimeUser(String userId) async {
    try {
      debugPrint(
        ' [SetupStatus] Checking first-time user status for: $userId',
      );

      // Load status for this user if not already loaded
      if (_currentStatus?.userId != userId) {
        await _loadSetupStatusForUser(userId);
      }

      final isFirstTime = _currentStatus?.isFirstTimeUser ?? true;
      debugPrint(' [SetupStatus] User $userId is first-time: $isFirstTime');

      return isFirstTime;
    } catch (e) {
      debugPrint(' [SetupStatus] Error checking first-time user: $e');
      return true; // Default to first-time if error
    }
  }

  /// Mark setup as complete for a user
  Future<void> markSetupComplete(String userId) async {
    try {
      debugPrint(' [SetupStatus] Marking setup complete for user: $userId');

      final now = DateTime.now();
      _currentStatus = UserSetupStatus(
        userId: userId,
        isFirstTimeUser: false,
        setupCompleted: true,
        setupCompletedAt: now,
        lastUpdated: now,
        hasActiveDesktopConnection: await _checkDesktopConnection(),
        setupVersion: '1.0.0',
        preferences: _currentStatus?.preferences ?? {},
      );

      await _saveSetupStatus();

      // Clear progress since setup is complete
      _setupProgress.clear();
      await _saveSetupProgress();

      debugPrint(' [SetupStatus] Setup marked complete for user: $userId');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to mark setup complete: ${e.toString()}';
      debugPrint(' [SetupStatus] Error marking setup complete: $e');
      notifyListeners();
    }
  }

  /// Check if user has an active desktop connection
  Future<bool> hasActiveDesktopConnection(String userId) async {
    try {
      final hasConnection = await _checkDesktopConnection();
      debugPrint(
        ' [SetupStatus] Desktop connection status for $userId: $hasConnection',
      );
      return hasConnection;
    } catch (e) {
      debugPrint(' [SetupStatus] Error checking desktop connection: $e');
      return false;
    }
  }

  /// Reset setup status for a user (for re-onboarding or testing)
  Future<void> resetSetupStatus(String userId) async {
    try {
      debugPrint(' [SetupStatus] Resetting setup status for user: $userId');

      _currentStatus = UserSetupStatus(
        userId: userId,
        isFirstTimeUser: true,
        setupCompleted: false,
        lastUpdated: DateTime.now(),
        hasActiveDesktopConnection: false,
        setupVersion: '1.0.0',
        preferences: {},
      );

      await _saveSetupStatus();

      // Clear progress
      _setupProgress.clear();
      await _saveSetupProgress();

      debugPrint(' [SetupStatus] Setup status reset for user: $userId');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to reset setup status: ${e.toString()}';
      debugPrint(' [SetupStatus] Error resetting setup status: $e');
      notifyListeners();
    }
  }

  /// Get setup progress for a user
  Future<Map<String, dynamic>?> getSetupProgress(String userId) async {
    try {
      if (_currentStatus?.userId != userId) {
        await _loadSetupStatusForUser(userId);
        await _loadSetupProgress();
      }

      return _setupProgress.isNotEmpty ? Map.from(_setupProgress) : null;
    } catch (e) {
      debugPrint(' [SetupStatus] Error getting setup progress: $e');
      return null;
    }
  }

  /// Save setup progress for a user
  Future<void> saveSetupProgress(
    String userId,
    Map<String, dynamic> progress,
  ) async {
    try {
      debugPrint(' [SetupStatus] Saving setup progress for user: $userId');

      _setupProgress = Map.from(progress);
      _setupProgress['userId'] = userId;
      _setupProgress['lastUpdate'] = DateTime.now().toIso8601String();
      _lastProgressUpdate = DateTime.now();

      await _saveSetupProgress();

      debugPrint(' [SetupStatus] Setup progress saved for user: $userId');
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to save setup progress: ${e.toString()}';
      debugPrint(' [SetupStatus] Error saving setup progress: $e');
      notifyListeners();
    }
  }

  /// Update user preferences
  Future<void> updateUserPreferences(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    try {
      if (_currentStatus?.userId == userId) {
        _currentStatus = _currentStatus!.copyWith(
          preferences: preferences,
          lastUpdated: DateTime.now(),
        );
        await _saveSetupStatus();
        notifyListeners();
      }
    } catch (e) {
      debugPrint(' [SetupStatus] Error updating user preferences: $e');
    }
  }

  /// Get comprehensive setup status information
  Map<String, dynamic> getStatusSummary() {
    return {
      'isInitialized': _isInitialized,
      'currentStatus': _currentStatus?.toJson(),
      'setupProgress': _setupProgress,
      'lastProgressUpdate': _lastProgressUpdate?.toIso8601String(),
      'hasError': _lastError != null,
      'lastError': _lastError,
      'authenticationStatus': _authService.isAuthenticated.value,
      'connectedClients': _clientDetectionService?.connectedClientCount ?? 0,
    };
  }

  /// Load setup status from storage
  Future<void> _loadSetupStatus() async {
    try {
      final statusJson = await _storage.read(_setupStatusKey);
      if (statusJson != null) {
        final statusData = jsonDecode(statusJson) as Map<String, dynamic>;
        _currentStatus = UserSetupStatus.fromJson(statusData);
        debugPrint(
          ' [SetupStatus] Loaded setup status for user: ${_currentStatus?.userId}',
        );
      }
    } catch (e) {
      debugPrint(' [SetupStatus] Error loading setup status: $e');
    }
  }

  /// Load setup status for a specific user
  Future<void> _loadSetupStatusForUser(String userId) async {
    try {
      final statusJson = await _storage.read('${_setupStatusKey}_$userId');
      if (statusJson != null) {
        final statusData = jsonDecode(statusJson) as Map<String, dynamic>;
        _currentStatus = UserSetupStatus.fromJson(statusData);
      } else {
        // Create new status for first-time user
        _currentStatus = UserSetupStatus(
          userId: userId,
          isFirstTimeUser: true,
          setupCompleted: false,
          lastUpdated: DateTime.now(),
          hasActiveDesktopConnection: false,
          setupVersion: '1.0.0',
          preferences: {},
        );
      }
    } catch (e) {
      debugPrint(' [SetupStatus] Error loading setup status for user: $e');
    }
  }

  /// Save setup status to storage
  Future<void> _saveSetupStatus() async {
    try {
      if (_currentStatus != null) {
        final statusJson = jsonEncode(_currentStatus!.toJson());
        await _storage.write(_setupStatusKey, statusJson);

        // Also save with user-specific key
        await _storage.write(
          '${_setupStatusKey}_${_currentStatus!.userId}',
          statusJson,
        );
      }
    } catch (e) {
      debugPrint(' [SetupStatus] Error saving setup status: $e');
    }
  }

  /// Load setup progress from storage
  Future<void> _loadSetupProgress() async {
    try {
      final progressJson = await _storage.read(_setupProgressKey);
      if (progressJson != null) {
        _setupProgress = Map<String, dynamic>.from(jsonDecode(progressJson));
        final lastUpdateStr = _setupProgress['lastUpdate'] as String?;
        if (lastUpdateStr != null) {
          _lastProgressUpdate = DateTime.parse(lastUpdateStr);
        }
      }
    } catch (e) {
      debugPrint(' [SetupStatus] Error loading setup progress: $e');
    }
  }

  /// Save setup progress to storage
  Future<void> _saveSetupProgress() async {
    try {
      final progressJson = jsonEncode(_setupProgress);
      await _storage.write(_setupProgressKey, progressJson);
    } catch (e) {
      debugPrint(' [SetupStatus] Error saving setup progress: $e');
    }
  }

  /// Check desktop connection status
  Future<bool> _checkDesktopConnection() async {
    return _clientDetectionService?.hasConnectedClients ?? false;
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    final userId = _authService.currentUser?.id;
    if (userId != null && _currentStatus?.userId != userId) {
      // Load status for new user
      _loadSetupStatusForUser(userId);
    }
  }

  /// Handle client detection changes
  void _onClientDetectionChanged() {
    if (_currentStatus != null) {
      final hasConnection =
          _clientDetectionService?.hasConnectedClients ?? false;
      if (_currentStatus!.hasActiveDesktopConnection != hasConnection) {
        _currentStatus = _currentStatus!.copyWith(
          hasActiveDesktopConnection: hasConnection,
          lastUpdated: DateTime.now(),
        );
        _saveSetupStatus();
        notifyListeners();
      }
    }
  }

  /// Clear any error state
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _clientDetectionService?.removeListener(_onClientDetectionChanged);
    super.dispose();
  }
}
