# Flutter Services

This directory contains the business logic and state management services for CloudToLocalLLM.

## Overview

Services in this directory follow these patterns:
- Extend `ChangeNotifier` for reactive state management
- Registered in `di/locator.dart` using get_it dependency injection
- Provided to widget tree via Provider in `main.dart`
- Core services (AuthService) always available
- Authenticated services registered after login

## Service Architecture

### Core Services (Always Available)

#### AuthService
- **Purpose**: Authentication and authorization management
- **Features**:
  - Auth0 OAuth2 integration
  - JWT token management with automatic refresh
  - Secure token storage via flutter_secure_storage
  - User session management
  - Auth state notifications
- **Dependencies**: None (core service)
- **Location**: `lib/services/auth_service.dart`

### Admin Center Services (Authenticated Only)

#### PaymentGatewayService
- **Purpose**: Payment processing and transaction management for Admin Center
- **Features**:
  - Payment transaction management
  - Subscription creation and lifecycle management
  - Refund processing with admin authentication
  - Payment method management (PCI DSS compliant)
  - Real-time data caching with timestamps
  - Automatic JWT token injection
  - Admin role validation
- **Dependencies**: AuthService, Dio HTTP client
- **API Endpoint**: `/api/admin/payments`
- **Location**: `lib/services/payment_gateway_service.dart`
- **Models**: `PaymentTransactionModel`, `SubscriptionModel`, `RefundModel`

## Service Registration

Services are registered in `lib/di/locator.dart`:

```dart
// Core services (always available)
locator.registerLazySingleton<AuthService>(() => AuthService());

// Admin services (registered after authentication)
void registerAdminServices() {
  locator.registerLazySingleton<PaymentGatewayService>(
    () => PaymentGatewayService(authService: locator<AuthService>())
  );
}
```

## Service Usage

### Accessing Services

```dart
// Via dependency injection
final authService = locator<AuthService>();
final paymentService = locator<PaymentGatewayService>();

// Via Provider (in widgets)
final authService = Provider.of<AuthService>(context, listen: false);
final paymentService = context.watch<PaymentGatewayService>();
```

### State Management Pattern

```dart
class MyService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
}
```

### Error Handling

All services follow consistent error handling:

```dart
try {
  _setLoading(true);
  _setError(null);
  
  // Perform operation
  final result = await _dio.get('/endpoint');
  
  _setLoading(false);
  return result;
} catch (e) {
  _setError('User-friendly error message');
  _setLoading(false);
  rethrow;
}
```

## HTTP Client Configuration

Services use Dio for HTTP requests with:
- Base URL from `AppConfig`
- Automatic JWT token injection
- Request/response interceptors
- Error handling and logging
- Timeout configuration

```dart
void _setupDio() {
  _dio.options.baseUrl = AppConfig.adminApiBaseUrl;
  _dio.options.connectTimeout = AppConfig.adminApiTimeout;
  
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
        // Handle errors
        handler.next(error);
      },
    ),
  );
}
```

## Authentication Flow

1. User initiates login → Auth0 OAuth flow
2. Callback handled by `/callback` route
3. JWT tokens stored in flutter_secure_storage
4. AuthService notifies listeners of auth state change
5. Admin services registered in DI container
6. Provider tree rebuilt with authenticated services

## Service Lifecycle

### Initialization
```dart
// In main.dart
void main() async {
  setupLocator(); // Register core services
  
  final authService = locator<AuthService>();
  await authService.initialize();
  
  if (authService.isAuthenticated.value) {
    registerAdminServices(); // Register authenticated services
  }
  
  runApp(MyApp());
}
```

### Cleanup
```dart
@override
void dispose() {
  _authService.removeListener(_onAuthStateChanged);
  _dio.close();
  super.dispose();
}
```

## Testing Services

```dart
void main() {
  late MockAuthService mockAuthService;
  late PaymentGatewayService paymentService;
  
  setUp(() {
    mockAuthService = MockAuthService();
    paymentService = PaymentGatewayService(
      authService: mockAuthService
    );
  });
  
  test('should fetch transactions', () async {
    // Test implementation
  });
}
```

## Best Practices

1. **Always extend ChangeNotifier** for reactive state
2. **Use private fields** with public getters for state
3. **Call notifyListeners()** after state changes
4. **Implement dispose()** to clean up resources
5. **Handle errors gracefully** with user-friendly messages
6. **Use dependency injection** for testability
7. **Cache data** when appropriate with timestamps
8. **Listen to auth state** for automatic cleanup
9. **Use interceptors** for cross-cutting concerns
10. **Log errors** for debugging and monitoring

## Future Services

Planned services for Admin Center:
- `UserManagementService` - User CRUD operations
- `SubscriptionManagementService` - Subscription lifecycle
- `AuditLogService` - Audit trail viewing
- `DashboardMetricsService` - Dashboard data
- `ReportingService` - Financial reports

## Documentation

- Admin Center Design: `.kiro/specs/admin-center/design.md`
- Admin Center Requirements: `.kiro/specs/admin-center/requirements.md`
- Admin API Reference: `docs/API/ADMIN_API.md`
- Models Documentation: `lib/models/README.md`

## Support

For issues or questions about services:
- Check service-specific documentation
- Review Admin Center design documents
- Consult API documentation
- Contact development team


## AdminCenterService (`admin_center_service.dart`)

**Status:** ✅ Implemented (Phase 1)

Comprehensive administrative service for the Admin Center providing role-based access control, user management, payment operations, and dashboard analytics.

### Features

- **Role-Based Access Control**: Permission checking and role validation
- **User Management**: List, view, suspend, and reactivate user accounts
- **Payment Management**: Transaction viewing and refund processing
- **Subscription Management**: View and manage user subscriptions
- **Dashboard Metrics**: Real-time analytics and system statistics
- **Audit Log Access**: View administrative action history

### Authentication & Authorization

- Connects to admin API backend at `/api/admin/*`
- Automatic JWT token injection via Dio interceptors
- Admin role validation (403 error handling)
- Permission-based method access control
- Requires admin privileges for all operations

### State Management

- Extends `ChangeNotifier` for reactive state updates
- Loading state management (`isLoading`)
- Error state management with user-friendly messages
- Cached data with timestamp tracking
- Auth state listener for automatic cleanup on logout

### Admin Roles

Supports three admin role types:
- **Super Admin**: Full system access (all permissions)
- **Support Admin**: User management and support operations
- **Finance Admin**: Payment and subscription management

### Permissions

Granular permission system:
- `view_users` - View user list and details
- `edit_users` - Update user information
- `suspend_users` - Suspend and reactivate accounts
- `view_payments` - View payment transactions
- `process_refunds` - Process refunds
- `view_subscriptions` - View subscription details
- `edit_subscriptions` - Modify subscriptions
- `view_reports` - Access financial reports
- `export_reports` - Export report data
- `view_audit_logs` - View audit trail
- `export_audit_logs` - Export audit logs

### Usage Example

```dart
// Initialize service
final adminService = AdminCenterService(authService: authService);
await adminService.initialize();

// Check permissions
if (adminService.hasPermission(AdminPermission.viewUsers)) {
  // User has permission to view users
}

// Check roles
if (adminService.isSuperAdmin) {
  // User is a Super Admin
}

// Access dashboard metrics
final metrics = adminService.dashboardMetrics;
```

### API Integration

- Base URL: `AppConfig.adminApiBaseUrl`
- Timeout: `AppConfig.adminApiTimeout`
- Authentication: Bearer token from `AuthService`
- Error handling: 403 (admin access denied), network errors, timeouts

### Dependencies

- `flutter/foundation.dart` - ChangeNotifier for state management
- `dio` - HTTP client for API requests
- `AuthService` - Authentication and token management
- `AppConfig` - Configuration constants
- Admin models: `AdminRoleModel`, `AdminAuditLogModel`

### Related Services

- `AuthService` - Provides JWT tokens and auth state
- `PaymentGatewayService` - Payment processing operations
- Backend API: `services/api-backend/routes/admin/*`

### Documentation

- Admin Center design: `.kiro/specs/admin-center/design.md`
- Admin API reference: `docs/API/ADMIN_API.md`
- Task completion: `.kiro/specs/admin-center/TASK_13_COMPLETION_SUMMARY.md`

### Lifecycle

1. **Initialization**: Call `initialize()` to load admin roles
2. **Permission Checking**: Use `hasPermission()` before operations
3. **Data Access**: Access cached data via getters
4. **Cleanup**: Automatically disposes on logout via auth listener

### Error Handling

- Network errors are caught and exposed via `error` getter
- 403 errors show admin access denied message
- All errors are logged for debugging
- `clearError()` method to reset error state

### Security Features

- JWT token validation on every request
- Admin role verification from database
- Permission-based access control
- Comprehensive audit logging (backend)
- Automatic session cleanup on logout

