import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/admin_role_model.dart';
import 'auth_service.dart';

/// Comprehensive administrative service for CloudToLocalLLM
///
/// Provides secure administrative functionality including:
///
/// **System Administration:**
/// - System monitoring and statistics
/// - Container and network management
/// - Configuration management
/// - Real-time performance metrics
///
/// **Admin Center:**
/// - Role-based access control and permission checking
/// - User management (list, details, suspend, reactivate)
/// - Payment transaction management
/// - Subscription management
/// - Dashboard metrics and analytics
/// - Audit log access
///
/// Features:
/// - Connects to admin API backend (/admin/*)
/// - JWT authentication with admin role validation
/// - Permission-based method access control
/// - Comprehensive error handling and logging
/// - Real-time data updates with caching
class AdminService extends ChangeNotifier {
  final Dio _dio;
  final AuthService _authService;

  // Service state
  bool _isLoading = false;
  String? _error;
  bool _isAdminAuthenticated = false;

  // Admin Center - Roles and permissions
  final List<AdminRoleModel> _adminRoles = [];

  // Admin Center - Cached data
  Map<String, dynamic>? _dashboardMetrics;
  DateTime? _lastDashboardMetricsUpdate;

  AdminService({required AuthService authService})
      : _authService = authService,
        _dio = Dio() {
    _setupDio();
    _authService.addListener(_onAuthStateChanged);
  }

  // Getters - Service state
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAdminAuthenticated => _isAdminAuthenticated;

  // Getters - Admin Center
  List<AdminRoleModel> get adminRoles => _adminRoles;
  Map<String, dynamic>? get dashboardMetrics => _dashboardMetrics;

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.adminApiBaseUrl;
    _dio.options.connectTimeout = AppConfig.adminApiTimeout;
    _dio.options.receiveTimeout = AppConfig.adminApiTimeout;

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
          debugPrint('❌ [AdminService] API Error: ${error.message}');
          if (error.response?.statusCode == 403) {
            _isAdminAuthenticated = false;
            _setError(
              'Admin access denied. Please ensure you have admin privileges.',
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated.value) {
      _isAdminAuthenticated = false;
      _clearAllData();
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearAllData() {
    _adminRoles.clear();
    _dashboardMetrics = null;
    _lastDashboardMetricsUpdate = null;
  }

  /// Clear any previous error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ============================================================================
  // Admin Center - Role and Permission Management
  // ============================================================================

  /// Load admin roles for the current user
  Future<bool> loadAdminRoles() async {
    try {
      debugPrint('👤 [AdminService] Loading admin roles');

      final response = await _dio.get('/admin/auth/roles');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final rolesList = response.data['data']['roles'] as List;
        _adminRoles.clear();
        _adminRoles.addAll(
          rolesList.map((json) => AdminRoleModel.fromJson(json)).toList(),
        );

        debugPrint('✅ [AdminService] Loaded ${_adminRoles.length} admin roles');
        notifyListeners();
        return true;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to load admin roles',
        );
      }
    } catch (e) {
      debugPrint('❌ [AdminService] Failed to load admin roles: $e');
      return false;
    }
  }

  /// Check if user has a specific admin role
  bool hasRole(AdminRole role) {
    return _adminRoles.any((r) => r.role == role && r.isActive);
  }

  /// Check if user has a specific permission
  bool hasPermission(AdminPermission permission) {
    for (final role in _adminRoles) {
      if (role.isActive && role.hasPermission(permission)) {
        return true;
      }
    }
    return false;
  }

  /// Check if user is a Super Admin
  bool get isSuperAdmin => hasRole(AdminRole.superAdmin);

  /// Check if user has any admin role
  bool get isAdmin => _adminRoles.any((r) => r.isActive);

  // ============================================================================
  // Admin Center - User Management Methods
  // ============================================================================

  /// Get users with pagination and filtering
  Future<Map<String, dynamic>?> getUsers({
    int page = 1,
    int limit = 50,
    String? search,
    String? tier,
    String? status,
  }) async {
    try {
      debugPrint('👥 [AdminService] Fetching users');
      _setLoading(true);
      _setError(null);

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (tier != null) queryParams['tier'] = tier;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/admin/users',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Fetched users successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch users',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch users: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get user details by ID
  Future<Map<String, dynamic>?> getUserDetails(String userId) async {
    try {
      debugPrint('👤 [AdminService] Fetching user details: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.get('/admin/users/$userId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] User details fetched');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch user details',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch user details: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user subscription tier
  Future<bool> updateUserSubscription({
    required String userId,
    required String newTier,
  }) async {
    try {
      debugPrint('📝 [AdminService] Updating user subscription: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.patch(
        '/admin/users/$userId/subscription',
        data: {'tier': newTier},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] User subscription updated');
        return true;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to update subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to update subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Suspend a user account
  Future<bool> suspendUser({
    required String userId,
    required String reason,
  }) async {
    try {
      debugPrint('🚫 [AdminService] Suspending user: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.post(
        '/admin/users/$userId/suspend',
        data: {'reason': reason},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] User suspended');
        return true;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to suspend user',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to suspend user: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reactivate a suspended user account
  Future<bool> reactivateUser(String userId) async {
    try {
      debugPrint('✅ [AdminService] Reactivating user: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.post('/admin/users/$userId/reactivate');

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] User reactivated');
        return true;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to reactivate user',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to reactivate user: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // Admin Center - Payment Management Methods
  // ============================================================================

  /// Get payment transactions with filtering
  Future<Map<String, dynamic>?> getTransactions({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      debugPrint('💳 [AdminService] Fetching transactions');
      _setLoading(true);
      _setError(null);

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (userId != null) queryParams['user_id'] = userId;
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/admin/payments/transactions',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Fetched transactions successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch transactions',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch transactions: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get transaction details by ID
  Future<Map<String, dynamic>?> getTransactionDetails(
    String transactionId,
  ) async {
    try {
      debugPrint(
          '💳 [AdminService] Fetching transaction details: $transactionId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/payments/transactions/$transactionId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Transaction details fetched');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch transaction details',
        );
      }
    } catch (e) {
      final errorMessage =
          'Failed to fetch transaction details: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Process a refund for a transaction
  Future<Map<String, dynamic>?> processRefund({
    required String transactionId,
    double? amount,
    required String reason,
    String? reasonDetails,
  }) async {
    try {
      debugPrint(
          '💰 [AdminService] Processing refund for transaction: $transactionId');
      _setLoading(true);
      _setError(null);

      final requestData = <String, dynamic>{
        'transaction_id': transactionId,
        'reason': reason,
      };

      if (amount != null) {
        requestData['amount'] = amount;
      }
      if (reasonDetails != null && reasonDetails.isNotEmpty) {
        requestData['reason_details'] = reasonDetails;
      }

      final response = await _dio.post(
        '/admin/payments/refunds',
        data: requestData,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Refund processed successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to process refund',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to process refund: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get payment methods for a user
  Future<List<Map<String, dynamic>>> getPaymentMethods(String userId) async {
    try {
      debugPrint(
          '💳 [AdminService] Fetching payment methods for user: $userId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/payments/methods/$userId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final methodsList = response.data['data']['payment_methods'] as List;
        final methods = List<Map<String, dynamic>>.from(methodsList);

        debugPrint(
            '✅ [AdminService] Fetched ${methods.length} payment methods');
        return methods;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch payment methods',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch payment methods: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // Admin Center - Subscription Management Methods
  // ============================================================================

  /// Get subscriptions with filtering
  Future<Map<String, dynamic>?> getSubscriptions({
    String? userId,
    String? tier,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      debugPrint('📋 [AdminService] Fetching subscriptions');
      _setLoading(true);
      _setError(null);

      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      if (userId != null) queryParams['user_id'] = userId;
      if (tier != null) queryParams['tier'] = tier;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/admin/subscriptions',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Fetched subscriptions successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch subscriptions',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch subscriptions: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Get subscription details by ID
  Future<Map<String, dynamic>?> getSubscriptionDetails(
    String subscriptionId,
  ) async {
    try {
      debugPrint(
          '📋 [AdminService] Fetching subscription details: $subscriptionId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.get(
        '/admin/subscriptions/$subscriptionId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Subscription details fetched');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch subscription details',
        );
      }
    } catch (e) {
      final errorMessage =
          'Failed to fetch subscription details: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Update a subscription (tier change)
  Future<Map<String, dynamic>?> updateSubscription({
    required String subscriptionId,
    required String newPriceId,
  }) async {
    try {
      debugPrint('📋 [AdminService] Updating subscription: $subscriptionId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.patch(
        '/admin/subscriptions/$subscriptionId',
        data: {'price_id': newPriceId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Subscription updated successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to update subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to update subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel a subscription
  Future<Map<String, dynamic>?> cancelSubscription({
    required String subscriptionId,
    bool immediate = false,
  }) async {
    try {
      debugPrint('📋 [AdminService] Canceling subscription: $subscriptionId');
      _setLoading(true);
      _setError(null);

      final response = await _dio.post(
        '/admin/subscriptions/$subscriptionId/cancel',
        data: {'immediate': immediate},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        debugPrint('✅ [AdminService] Subscription canceled successfully');
        return response.data['data'];
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to cancel subscription',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to cancel subscription: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================================
  // Admin Center - Dashboard Metrics Methods
  // ============================================================================

  /// Get dashboard metrics
  Future<bool> getDashboardMetrics({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _dashboardMetrics != null &&
        _lastDashboardMetricsUpdate != null &&
        DateTime.now().difference(_lastDashboardMetricsUpdate!).inMinutes < 5) {
      return true;
    }

    try {
      debugPrint('📊 [AdminService] Fetching dashboard metrics');
      _setLoading(true);
      _setError(null);

      final response = await _dio.get('/admin/dashboard/metrics');

      if (response.statusCode == 200 && response.data['success'] == true) {
        _dashboardMetrics = response.data['data'];
        _lastDashboardMetricsUpdate = DateTime.now();

        debugPrint('✅ [AdminService] Dashboard metrics updated');
        notifyListeners();
        return true;
      } else {
        throw Exception(
          response.data['error'] ?? 'Failed to fetch dashboard metrics',
        );
      }
    } catch (e) {
      final errorMessage = 'Failed to fetch dashboard metrics: ${e.toString()}';
      _setError(errorMessage);
      debugPrint('❌ [AdminService] $errorMessage');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refresh dashboard metrics (force refresh)
  Future<bool> refreshDashboardMetrics() async {
    return getDashboardMetrics(forceRefresh: true);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _dio.close();
    super.dispose();
  }
}
