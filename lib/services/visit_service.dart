import 'dart:convert';

import '../models.dart';
import 'api_service.dart';
import 'building_service.dart';
import 'cache_service.dart';

/// Service for visit CRUD and status management.
///
/// All methods throw [ApiException] on failure.
/// Responses are cached for 2 minutes.
class VisitService {
  VisitService._();
  static final VisitService instance = VisitService._();

  static const int _cacheTtlSeconds = 120;

  // ---------------------------------------------------------------------------
  // Visits
  // ---------------------------------------------------------------------------

  /// GET /visits?dateFrom=…&dateTo=…&status=…&page=…&limit=…
  Future<PaginatedResult<VisitItem>> getVisits({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey =
        'visits_${dateFrom?.toIso8601String().split('T').first ?? '_'}_${dateTo?.toIso8601String().split('T').first ?? '_'}_${status ?? '_'}_p${page}_l$limit';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parseVisitsPage(cached, page, limit);
      }
    }

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (dateFrom != null) {
      params['dateFrom'] = dateFrom.toIso8601String().split('T').first;
    }
    if (dateTo != null) {
      params['dateTo'] = dateTo.toIso8601String().split('T').first;
    }
    if (status != null && status.isNotEmpty) params['status'] = status;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final result = await ApiService.instance.get('/visits?$query');

    final raw = jsonEncode(result);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return _parseVisitsPage(raw, page, limit);
  }

  PaginatedResult<VisitItem> _parseVisitsPage(
    String raw,
    int page,
    int limit,
  ) {
    final result = jsonDecode(raw) as Map<String, dynamic>;
    final data = result['data'];
    final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

    final items = (data as List<dynamic>)
        .map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedResult<VisitItem>(
      items: items,
      total: (metadata['total'] as num?)?.toInt() ?? items.length,
      page: (metadata['page'] as num?)?.toInt() ?? page,
      limit: (metadata['limit'] as num?)?.toInt() ?? limit,
      totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
      hasMore: (metadata['hasMore'] as bool?) ?? false,
    );
  }

  /// GET /visits/:id
  Future<VisitItem> getVisit(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'visit_$id';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return VisitItem.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/visits/$id');
    final data = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, data, ttlSeconds: _cacheTtlSeconds);
    return VisitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /visits
  /// Returns the created visit and optionally the [occupantSMS] map
  /// if the backend sent an SMS to the unit occupant.
  Future<({VisitItem visit, Map<String, dynamic>? occupantSMS})> createVisit(
      Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/visits', data);
    CacheService.instance.invalidateAll();
    final visit = VisitItem.fromJson(result['data'] as Map<String, dynamic>);
    final occupantSMS = result['occupantSMS'] as Map<String, dynamic>?;
    return (visit: visit, occupantSMS: occupantSMS);
  }

  /// PUT /visits/:id
  Future<VisitItem> updateVisit(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.put('/visits/$id', data);
    CacheService.instance.invalidateAll();
    return VisitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PATCH /visits/:id/status — change visit status (e.g. confirm, cancel).
  Future<VisitItem> updateVisitStatus(
    String id,
    String newStatus, {
    String? outcome,
    String? reasonCode,
    String? notes,
  }) async {
    final payload = <String, dynamic>{'status': newStatus};
    if (outcome != null) payload['outcome'] = outcome;
    if (reasonCode != null) payload['reasonCode'] = reasonCode;
    if (notes != null) payload['notes'] = notes;
    final result = await ApiService.instance.patch(
      '/visits/$id/status',
      payload,
    );
    CacheService.instance.invalidateAll();
    return VisitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /visits/:id
  Future<void> deleteVisit(String id) async {
    await ApiService.instance.delete('/visits/$id');
    CacheService.instance.invalidateAll();
  }

  /// PATCH /visits/:id/reschedule — reschedule and optionally send re-confirmation SMS.
  Future<VisitItem> rescheduleVisit(
    String id, {
    required DateTime newDateTime,
    bool sendSms = true,
    String? notes,
  }) async {
    final result = await ApiService.instance.patch(
      '/visits/$id/reschedule',
      {
        'dateTime': newDateTime.toIso8601String(),
        'sendSms': sendSms,
        if (notes != null) 'notes': notes,
      },
    );
    CacheService.instance.invalidateAll();
    return VisitItem.fromJson(result['data'] as Map<String, dynamic>);
  }
}
