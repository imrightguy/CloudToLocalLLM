/// LLM Audit Service
/// Tracks and audits LLM usage for compliance and analytics
library;

import 'package:cloudtolocalllm/services/auth_service.dart';

class LLMAuditService {
  LLMAuditService({required AuthService authService});

  /// Initialize the audit service
  Future<void> initialize() async {
    // Stub - no-op
  }

  /// Log an LLM request
  Future<void> logRequest({
    required String providerId,
    required String model,
    required int promptTokens,
    required int completionTokens,
    required Duration latency,
  }) async {
    // Stub - no-op
  }

  /// Log an LLM error
  Future<void> logError({
    required String providerId,
    required String error,
    required String? stackTrace,
  }) async {
    // Stub - no-op
  }

  /// Get audit logs for a time period
  Future<List<Map<String, dynamic>>> getAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Stub - returns empty list
    return [];
  }
}
