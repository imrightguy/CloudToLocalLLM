import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/admin_role_model.dart';
import 'auth_service.dart';
import '../config/app_config.dart';
import '../utils/file_download_helper.dart';

/// Admin Center service for managing users, payments, subscriptions, and reports.
/// Provides role-based access control and permission management.
class AdminCenterService extends ChangeNotifier {
  final AuthService _authService;
  final Dio _dio;

  // State
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  List<AdminRoleModel> _adminRoles = [];
  Map<String, dynamic>? _dashboardMetrics;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  List<AdminRoleModel> get adminRoles => _adminRoles;
  Map<String, dynamic>? get dashboardMetrics => _dashboardMetrics;

  AdminCenterService({
    required AuthService authService,
    Dio? dio,
  })  : _authService = authService,
        _dio = dio ?? Dio() {
    _setupDio();
    _authService.addListener(_onAuthStateChanged);
  }

  /// Setup Dio with interceptors
  void _setupDio() {
    _dio.options.baseUrl = AppConfig.adminApiBaseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);

    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _authService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 403) {
          _setError(
              'Admin access denied. You do not have permission to perform this action.');
        }
        return handler.next(error);
      },
    ));
  }

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      await _loadAdminRoles();
      _isInitialized = true;
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error initializing: $e');
      _setError('Failed to initialize admin service: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load admin roles for current user
  Future<void> _loadAdminRoles() async {
    try {
      final response = await _dio.get('/admin/auth/roles');
      final roles = (response.data['roles'] as List)
          .map((json) => AdminRoleModel.fromJson(json))
          .toList();
      _adminRoles = roles;
    } catch (e) {
      debugPrint('[AdminCenterService] Error loading admin roles: $e');
      rethrow;
    }
  }

  /// Check if user has a specific role
  bool hasRole(AdminRole role) {
    return _adminRoles.any((r) => r.role == role && r.isActive);
  }

  /// Check if user has a specific permission
  bool hasPermission(AdminPermission permission) {
    return _adminRoles
        .any((role) => role.isActive && role.hasPermission(permission));
  }

  /// Check if user is a super admin
  bool get isSuperAdmin => hasRole(AdminRole.superAdmin);

  /// Check if user has any admin role
  bool get isAdmin => _adminRoles.any((role) => role.isActive);

  /// Get Dio instance for direct API calls
  Dio getDio() => _dio;

  /// Get users with pagination and filtering
  Future<Map<String, dynamic>> getUsers({
    int page = 1,
    int limit = 50,
    String? search,
    String? tier,
    String? status,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        'page': page,
        'limit': limit,
        if (search != null) 'search': search,
        if (tier != null) 'tier': tier,
        if (status != null) 'status': status,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response =
          await _dio.get('/admin/users', queryParameters: queryParams);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting users: $e');
      _setError('Failed to load users: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get user details
  Future<Map<String, dynamic>> getUserDetails(String userId) async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/users/$userId');
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting user details: $e');
      _setError('Failed to load user details: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update user subscription
  Future<void> updateUserSubscription(String userId, String tier) async {
    try {
      _setLoading(true);
      await _dio.patch('/admin/users/$userId', data: {'tier': tier});
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error updating user subscription: $e');
      _setError('Failed to update subscription: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Suspend user account
  Future<void> suspendUser(String userId, String reason) async {
    try {
      _setLoading(true);
      await _dio.post('/admin/users/$userId/suspend', data: {'reason': reason});
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error suspending user: $e');
      _setError('Failed to suspend user: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Reactivate user account
  Future<void> reactivateUser(String userId) async {
    try {
      _setLoading(true);
      await _dio.post('/admin/users/$userId/reactivate');
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error reactivating user: $e');
      _setError('Failed to reactivate user: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get dashboard metrics
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/dashboard/metrics');
      _dashboardMetrics = response.data;
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting dashboard metrics: $e');
      _setError('Failed to load dashboard metrics: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get revenue report
  Future<Map<String, dynamic>> getRevenueReport({
    required DateTime startDate,
    required DateTime endDate,
    bool groupBy = true,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        'startDate': startDate.toIso8601String().split('T')[0],
        'endDate': endDate.toIso8601String().split('T')[0],
        'groupBy': groupBy.toString(),
      };

      final response = await _dio.get(
        '/admin/reports/revenue',
        queryParameters: queryParams,
      );
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting revenue report: $e');
      _setError('Failed to load revenue report: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get subscription metrics
  Future<Map<String, dynamic>> getSubscriptionMetrics({
    required DateTime startDate,
    required DateTime endDate,
    bool groupBy = true,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        'startDate': startDate.toIso8601String().split('T')[0],
        'endDate': endDate.toIso8601String().split('T')[0],
        'groupBy': groupBy.toString(),
      };

      final response = await _dio.get(
        '/admin/reports/subscriptions',
        queryParameters: queryParams,
      );
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting subscription metrics: $e');
      _setError('Failed to load subscription metrics: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Export report
  Future<void> exportReport({
    required String type,
    required String format,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        'type': type,
        'format': format,
        'startDate': startDate.toIso8601String().split('T')[0],
        'endDate': endDate.toIso8601String().split('T')[0],
      };

      final response = await _dio.get(
        '/admin/reports/export',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // Trigger file download
      final filename =
          '${type}_report_${startDate.toIso8601String().split('T')[0]}_${endDate.toIso8601String().split('T')[0]}.$format';
      final mimeType = format == 'pdf' ? 'application/pdf' : 'text/csv';

      downloadFile(response.data as List<int>, filename, mimeType);

      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error exporting report: $e');
      _setError('Failed to export report: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get audit logs with pagination and filtering
  Future<Map<String, dynamic>> getAuditLogs({
    int page = 1,
    int limit = 100,
    String? adminUserId,
    String? action,
    String? resourceType,
    String? affectedUserId,
    DateTime? startDate,
    DateTime? endDate,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        'page': page,
        'limit': limit,
        if (adminUserId != null) 'adminUserId': adminUserId,
        if (action != null) 'action': action,
        if (resourceType != null) 'resourceType': resourceType,
        if (affectedUserId != null) 'affectedUserId': affectedUserId,
        if (startDate != null)
          'startDate': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await _dio.get(
        '/admin/audit/logs',
        queryParameters: queryParams,
      );
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting audit logs: $e');
      _setError('Failed to load audit logs: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get audit log details by ID
  Future<Map<String, dynamic>> getAuditLogDetails(String logId) async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/audit/logs/$logId');
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting audit log details: $e');
      _setError('Failed to load audit log details: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Export audit logs to CSV
  Future<void> exportAuditLogs({
    String? adminUserId,
    String? action,
    String? resourceType,
    String? affectedUserId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        if (adminUserId != null) 'adminUserId': adminUserId,
        if (action != null) 'action': action,
        if (resourceType != null) 'resourceType': resourceType,
        if (affectedUserId != null) 'affectedUserId': affectedUserId,
        if (startDate != null)
          'startDate': startDate.toIso8601String().split('T')[0],
        if (endDate != null) 'endDate': endDate.toIso8601String().split('T')[0],
      };

      final response = await _dio.get(
        '/admin/audit/export',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      // Trigger file download
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final filename = 'audit-logs-$timestamp.csv';
      const mimeType = 'text/csv';

      downloadFile(response.data as List<int>, filename, mimeType);

      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error exporting audit logs: $e');
      _setError('Failed to export audit logs: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get email configuration
  /// Endpoint: GET /admin/email/config
  Future<Map<String, dynamic>> getEmailConfiguration() async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/email/config');
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting email configuration: $e');
      _setError('Failed to load email configuration: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Save email configuration
  /// Endpoint: POST /admin/email/config
  Future<Map<String, dynamic>> saveEmailConfiguration(
    Map<String, dynamic> config,
  ) async {
    try {
      _setLoading(true);
      final response = await _dio.post(
        '/admin/email/config',
        data: config,
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error saving email configuration: $e');
      _setError('Failed to save email configuration: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Send test email
  /// Endpoint: POST /admin/email/test
  Future<Map<String, dynamic>> sendTestEmail(String recipientEmail) async {
    try {
      _setLoading(true);
      final response = await _dio.post(
        '/admin/email/test',
        data: {
          'recipientEmail': recipientEmail,
          'subject': 'Test Email from CloudToLocalLLM',
        },
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error sending test email: $e');
      _setError('Failed to send test email: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Start Google Workspace OAuth flow
  /// Endpoint: POST /admin/email/oauth/start
  Future<String> startEmailOAuthFlow() async {
    try {
      _setLoading(true);
      final response = await _dio.post('/admin/email/oauth/start');
      _setError(null);
      return response.data['data']['authorizationUrl'] ?? '';
    } catch (e) {
      debugPrint('[AdminCenterService] Error starting OAuth flow: $e');
      _setError('Failed to start OAuth flow: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Handle Google Workspace OAuth callback
  /// Endpoint: POST /admin/email/oauth/callback
  Future<Map<String, dynamic>> handleEmailOAuthCallback(
    String code,
    String state,
  ) async {
    try {
      _setLoading(true);
      final response = await _dio.post(
        '/admin/email/oauth/callback',
        data: {
          'code': code,
          'state': state,
        },
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error handling OAuth callback: $e');
      _setError('Failed to handle OAuth callback: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get email service status
  /// Endpoint: GET /admin/email/status
  Future<Map<String, dynamic>> getEmailStatus() async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/email/status');
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting email status: $e');
      _setError('Failed to load email status: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get Google Workspace quota usage
  /// Endpoint: GET /admin/email/quota
  Future<Map<String, dynamic>> getEmailQuota() async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/email/quota');
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting email quota: $e');
      _setError('Failed to load email quota: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get DNS records from Cloudflare
  /// Endpoint: GET /admin/dns/records
  Future<List<Map<String, dynamic>>> getDnsRecords({
    String? recordType,
    String? name,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        if (recordType != null) 'recordType': recordType,
        if (name != null) 'name': name,
      };

      final response = await _dio.get(
        '/admin/dns/records',
        queryParameters: queryParams,
      );
      _setError(null);
      final records = response.data['data']['records'] as List;
      return records.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting DNS records: $e');
      _setError('Failed to load DNS records: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Create a DNS record via Cloudflare
  /// Endpoint: POST /admin/dns/records
  Future<Map<String, dynamic>> createDnsRecord({
    required String recordType,
    required String name,
    required String value,
    int ttl = 3600,
    int? priority,
  }) async {
    try {
      _setLoading(true);
      final response = await _dio.post(
        '/admin/dns/records',
        data: {
          'recordType': recordType,
          'name': name,
          'value': value,
          'ttl': ttl,
          if (priority != null) 'priority': priority,
        },
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error creating DNS record: $e');
      _setError('Failed to create DNS record: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Update a DNS record via Cloudflare
  /// Endpoint: PUT /admin/dns/records/:id
  Future<Map<String, dynamic>> updateDnsRecord({
    required String recordId,
    String? value,
    int? ttl,
    int? priority,
  }) async {
    try {
      _setLoading(true);
      final response = await _dio.put(
        '/admin/dns/records/$recordId',
        data: {
          if (value != null) 'value': value,
          if (ttl != null) 'ttl': ttl,
          if (priority != null) 'priority': priority,
        },
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error updating DNS record: $e');
      _setError('Failed to update DNS record: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a DNS record via Cloudflare
  /// Endpoint: DELETE /admin/dns/records/:id
  Future<void> deleteDnsRecord(String recordId) async {
    try {
      _setLoading(true);
      await _dio.delete('/admin/dns/records/$recordId');
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error deleting DNS record: $e');
      _setError('Failed to delete DNS record: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Validate DNS records via Cloudflare
  /// Endpoint: POST /admin/dns/validate
  Future<Map<String, dynamic>> validateDnsRecords({String? recordId}) async {
    try {
      _setLoading(true);
      final queryParams = {
        if (recordId != null) 'recordId': recordId,
      };

      final response = await _dio.post(
        '/admin/dns/validate',
        queryParameters: queryParams,
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint('[AdminCenterService] Error validating DNS records: $e');
      _setError('Failed to validate DNS records: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get recommended DNS records for Google Workspace
  /// Endpoint: GET /admin/dns/google-records
  Future<Map<String, dynamic>> getGoogleWorkspaceDnsRecords({
    String? domain,
  }) async {
    try {
      _setLoading(true);
      final queryParams = {
        if (domain != null) 'domain': domain,
      };

      final response = await _dio.get(
        '/admin/dns/google-records',
        queryParameters: queryParams,
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint(
          '[AdminCenterService] Error getting Google Workspace DNS records: $e');
      _setError('Failed to load Google Workspace DNS records: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// One-click setup of Google Workspace DNS records
  /// Endpoint: POST /admin/dns/setup-google
  Future<Map<String, dynamic>> setupGoogleWorkspaceDns({
    String? domain,
    List<String>? recordTypes,
  }) async {
    try {
      _setLoading(true);
      final response = await _dio.post(
        '/admin/dns/setup-google',
        data: {
          if (domain != null) 'domain': domain,
          if (recordTypes != null) 'recordTypes': recordTypes,
        },
      );
      _setError(null);
      return response.data['data'] ?? {};
    } catch (e) {
      debugPrint(
          '[AdminCenterService] Error setting up Google Workspace DNS: $e');
      _setError('Failed to setup Google Workspace DNS: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get all administrators with their roles and activity summary
  /// Requires Super Admin role
  Future<Map<String, dynamic>> getAdmins() async {
    try {
      _setLoading(true);
      final response = await _dio.get('/admin/admins');
      _setError(null);
      return response.data;
    } catch (e) {
      debugPrint('[AdminCenterService] Error getting admins: $e');
      _setError('Failed to load administrators: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Assign admin role to a user
  /// Requires Super Admin role
  Future<void> assignAdminRole(String email, AdminRole role) async {
    try {
      _setLoading(true);

      // Convert AdminRole enum to backend role string
      String roleString;
      switch (role) {
        case AdminRole.supportAdmin:
          roleString = 'support_admin';
          break;
        case AdminRole.financeAdmin:
          roleString = 'finance_admin';
          break;
        case AdminRole.superAdmin:
          roleString = 'super_admin';
          break;
      }

      await _dio.post('/admin/admins', data: {
        'email': email,
        'role': roleString,
      });
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error assigning admin role: $e');
      _setError('Failed to assign admin role: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Revoke admin role from a user
  /// Requires Super Admin role
  Future<void> revokeAdminRole(String userId, String role) async {
    try {
      _setLoading(true);
      await _dio.delete('/admin/admins/$userId/roles/$role');
      _setError(null);
    } catch (e) {
      debugPrint('[AdminCenterService] Error revoking admin role: $e');
      _setError('Failed to revoke admin role: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear error
  void clearError() {
    _setError(null);
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Handle auth state changes
  void _onAuthStateChanged() {
    if (!_authService.isAuthenticated.value) {
      // Clear cached data on logout
      _adminRoles = [];
      _dashboardMetrics = null;
      _isInitialized = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthStateChanged);
    _dio.close();
    super.dispose();
  }
}
