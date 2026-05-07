import '../services/api_service.dart';

class TenantChecklistService {
  TenantChecklistService._();
  static final TenantChecklistService instance = TenantChecklistService._();

  Future<Map<String, dynamic>> startChecklist({
    required String unitId,
    String? leaseId,
    required String checklistType,
    String? tenantName,
    String? tenantPhone,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await ApiService.instance.post('/tenant-checklists/start', {
      'unitId': unitId,
      if (leaseId != null && leaseId.isNotEmpty) 'leaseId': leaseId,
      'checklistType': checklistType,
      if (tenantName != null && tenantName.isNotEmpty) 'tenantName': tenantName,
      if (tenantPhone != null && tenantPhone.isNotEmpty) 'tenantPhone': tenantPhone,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resumeChecklist(
    String sessionId, {
    String? resumedByUserId,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await ApiService.instance.post('/tenant-checklists/$sessionId/resume', {
      if (resumedByUserId != null && resumedByUserId.isNotEmpty) 'resumedByUserId': resumedByUserId,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pauseChecklist(
    String sessionId, {
    String? reason,
    String? pausedByUserId,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await ApiService.instance.post('/tenant-checklists/$sessionId/pause', {
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (pausedByUserId != null && pausedByUserId.isNotEmpty) 'pausedByUserId': pausedByUserId,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitChecklist(
    String sessionId, {
    String? confirmationNote,
    bool forceComplete = false,
    List<Map<String, dynamic>> stepUpdates = const [],
    List<Map<String, dynamic>> attachments = const [],
    List<Map<String, dynamic>> signatures = const [],
    String? submittedByUserId,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await ApiService.instance.post('/tenant-checklists/$sessionId/submit', {
      if (submittedByUserId != null && submittedByUserId.isNotEmpty) 'submittedByUserId': submittedByUserId,
      if (confirmationNote != null && confirmationNote.isNotEmpty) 'confirmationNote': confirmationNote,
      'forceComplete': forceComplete,
      'stepUpdates': stepUpdates,
      'attachments': attachments,
      'signatures': signatures,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchSummary(String sessionId, {bool managerView = false}) async {
    final path = managerView
        ? '/tenant-checklists/$sessionId/manager-summary'
        : '/tenant-checklists/$sessionId/summary';
    final result = await ApiService.instance.get(path);
    return result['data'] as Map<String, dynamic>;
  }
}
