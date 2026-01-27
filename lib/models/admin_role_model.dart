/// Admin role model for Admin Center
/// Represents an administrator's role and permissions
class AdminRoleModel {
  final String id;
  final String userId;
  final AdminRole role;
  final String? grantedBy;
  final DateTime grantedAt;
  final DateTime? revokedAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdminRoleModel({
    required this.id,
    required this.userId,
    required this.role,
    this.grantedBy,
    required this.grantedAt,
    this.revokedAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create AdminRoleModel from JSON
  factory AdminRoleModel.fromJson(Map<String, dynamic> json) {
    return AdminRoleModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? json['userId'] ?? '',
      role: _parseRole(json['role']),
      grantedBy: json['granted_by'] ?? json['grantedBy'],
      grantedAt:
          DateTime.tryParse(json['granted_at'] ?? json['grantedAt'] ?? '') ??
              DateTime.now(),
      revokedAt: json['revoked_at'] != null
          ? DateTime.tryParse(json['revoked_at'])
          : (json['revokedAt'] != null
              ? DateTime.tryParse(json['revokedAt'])
              : null),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['createdAt'] ?? '') ??
              DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? json['updatedAt'] ?? '') ??
              DateTime.now(),
    );
  }

  /// Convert AdminRoleModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role.value,
      'granted_by': grantedBy,
      'granted_at': grantedAt.toIso8601String(),
      'revoked_at': revokedAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Parse role from string
  static AdminRole _parseRole(dynamic value) {
    if (value == null) return AdminRole.supportAdmin;
    final roleStr = value.toString().toLowerCase();
    return AdminRole.values.firstWhere(
      (r) => r.value == roleStr,
      orElse: () => AdminRole.supportAdmin,
    );
  }

  /// Check if user has a specific permission
  bool hasPermission(AdminPermission permission) {
    return role.permissions.contains(permission);
  }

  /// Check if user has any of the specified permissions
  bool hasAnyPermission(List<AdminPermission> permissions) {
    return permissions.any(hasPermission);
  }

  /// Check if user has all of the specified permissions
  bool hasAllPermissions(List<AdminPermission> permissions) {
    return permissions.every(hasPermission);
  }

  /// Check if role is Super Admin
  bool get isSuperAdmin => role == AdminRole.superAdmin;

  /// Check if role is Support Admin
  bool get isSupportAdmin => role == AdminRole.supportAdmin;

  /// Check if role is Finance Admin
  bool get isFinanceAdmin => role == AdminRole.financeAdmin;

  /// Copy with method for immutable updates
  AdminRoleModel copyWith({
    String? id,
    String? userId,
    AdminRole? role,
    String? grantedBy,
    DateTime? grantedAt,
    DateTime? revokedAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminRoleModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      grantedBy: grantedBy ?? this.grantedBy,
      grantedAt: grantedAt ?? this.grantedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdminRoleModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'AdminRoleModel(id: $id, userId: $userId, role: ${role.value}, isActive: $isActive)';
  }
}

/// Admin role enum
enum AdminRole {
  superAdmin('super_admin'),
  supportAdmin('support_admin'),
  financeAdmin('finance_admin');

  final String value;
  const AdminRole(this.value);

  /// Get display name for role
  String get displayName {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.supportAdmin:
        return 'Support Admin';
      case AdminRole.financeAdmin:
        return 'Finance Admin';
    }
  }

  /// Get role description
  String get description {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Full access to all features including admin management';
      case AdminRole.supportAdmin:
        return 'User management and account support, view-only access to payments';
      case AdminRole.financeAdmin:
        return 'Payment management, refunds, and financial reports';
    }
  }

  /// Get permissions for this role
  List<AdminPermission> get permissions {
    switch (this) {
      case AdminRole.superAdmin:
        return AdminPermission.values; // All permissions
      case AdminRole.supportAdmin:
        return [
          AdminPermission.viewUsers,
          AdminPermission.editUsers,
          AdminPermission.suspendUsers,
          AdminPermission.viewSessions,
          AdminPermission.terminateSessions,
          AdminPermission.viewPayments,
          AdminPermission.viewAuditLogs,
        ];
      case AdminRole.financeAdmin:
        return [
          AdminPermission.viewUsers,
          AdminPermission.viewPayments,
          AdminPermission.processRefunds,
          AdminPermission.viewSubscriptions,
          AdminPermission.editSubscriptions,
          AdminPermission.viewReports,
          AdminPermission.exportReports,
          AdminPermission.viewAuditLogs,
        ];
    }
  }

  /// Get role from string value
  static AdminRole fromString(String value) {
    return AdminRole.values.firstWhere(
      (role) => role.value == value.toLowerCase(),
      orElse: () => AdminRole.supportAdmin,
    );
  }
}

/// Admin permission enum
enum AdminPermission {
  // User management
  viewUsers('view_users'),
  editUsers('edit_users'),
  suspendUsers('suspend_users'),
  deleteUsers('delete_users'),
  viewSessions('view_sessions'),
  terminateSessions('terminate_sessions'),

  // Payment management
  viewPayments('view_payments'),
  processRefunds('process_refunds'),
  viewPaymentMethods('view_payment_methods'),
  deletePaymentMethods('delete_payment_methods'),

  // Subscription management
  viewSubscriptions('view_subscriptions'),
  editSubscriptions('edit_subscriptions'),
  cancelSubscriptions('cancel_subscriptions'),

  // Reporting
  viewReports('view_reports'),
  exportReports('export_reports'),

  // Admin management
  viewAdmins('view_admins'),
  createAdmins('create_admins'),
  editAdmins('edit_admins'),
  deleteAdmins('delete_admins'),

  // Configuration
  viewConfiguration('view_configuration'),
  editConfiguration('edit_configuration'),

  // Audit logs
  viewAuditLogs('view_audit_logs'),
  exportAuditLogs('export_audit_logs');

  final String value;
  const AdminPermission(this.value);

  /// Get display name for permission
  String get displayName {
    switch (this) {
      case AdminPermission.viewUsers:
        return 'View Users';
      case AdminPermission.editUsers:
        return 'Edit Users';
      case AdminPermission.suspendUsers:
        return 'Suspend Users';
      case AdminPermission.deleteUsers:
        return 'Delete Users';
      case AdminPermission.viewSessions:
        return 'View Sessions';
      case AdminPermission.terminateSessions:
        return 'Terminate Sessions';
      case AdminPermission.viewPayments:
        return 'View Payments';
      case AdminPermission.processRefunds:
        return 'Process Refunds';
      case AdminPermission.viewPaymentMethods:
        return 'View Payment Methods';
      case AdminPermission.deletePaymentMethods:
        return 'Delete Payment Methods';
      case AdminPermission.viewSubscriptions:
        return 'View Subscriptions';
      case AdminPermission.editSubscriptions:
        return 'Edit Subscriptions';
      case AdminPermission.cancelSubscriptions:
        return 'Cancel Subscriptions';
      case AdminPermission.viewReports:
        return 'View Reports';
      case AdminPermission.exportReports:
        return 'Export Reports';
      case AdminPermission.viewAdmins:
        return 'View Admins';
      case AdminPermission.createAdmins:
        return 'Create Admins';
      case AdminPermission.editAdmins:
        return 'Edit Admins';
      case AdminPermission.deleteAdmins:
        return 'Delete Admins';
      case AdminPermission.viewConfiguration:
        return 'View Configuration';
      case AdminPermission.editConfiguration:
        return 'Edit Configuration';
      case AdminPermission.viewAuditLogs:
        return 'View Audit Logs';
      case AdminPermission.exportAuditLogs:
        return 'Export Audit Logs';
    }
  }

  /// Get permission from string value
  static AdminPermission fromString(String value) {
    return AdminPermission.values.firstWhere(
      (permission) => permission.value == value.toLowerCase(),
      orElse: () => AdminPermission.viewUsers,
    );
  }

  /// Get permission category
  String get category {
    if (value.contains('user')) return 'User Management';
    if (value.contains('payment')) return 'Payment Management';
    if (value.contains('subscription')) return 'Subscription Management';
    if (value.contains('report')) return 'Reporting';
    if (value.contains('admin')) return 'Admin Management';
    if (value.contains('configuration')) return 'Configuration';
    if (value.contains('audit')) return 'Audit Logs';
    if (value.contains('session')) return 'Session Management';
    return 'Other';
  }
}
