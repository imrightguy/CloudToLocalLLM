import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_config.dart';
import '../models.dart';
import 'api_service.dart';
import 'auth_token_storage.dart';
import 'building_service.dart';
import 'cache_service.dart';

/// Service for lead CRUD and pipeline stage management.
///
/// All methods throw [ApiException] on failure.
/// Responses are cached for 2 minutes (leads change frequently).
class LeadService {
  LeadService._();
  static final LeadService instance = LeadService._();

  static const int _cacheTtlSeconds = 120;

  // ---------------------------------------------------------------------------
  // Leads
  // ---------------------------------------------------------------------------

  /// GET /leads?stage=…&search=…&page=…&limit=…
  Future<PaginatedResult<LeadItem>> getLeads({
    LeadStage? stage,
    String? search,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'leads_${stage?.name ?? '_'}_${search ?? ''}_p$page';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parseLeadsPage(cached, page, limit);
      }
    }

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (stage != null) params['stage'] = stage.name;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    // Bypass ApiService — direct HTTP call to isolate the bug
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/leads?$query');
    final token = await _getAccessToken();
    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    });

    if (response.statusCode != 200) {
      throw ApiException('Leads fetch failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true) {
      throw ApiException('Leads fetch failed: ${body['error']?['message'] ?? 'unknown'}');
    }

    final dataList = body['data'];
    final items = (dataList is List)
        ? dataList
            .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <LeadItem>[];
    final metadata = body['metadata'] as Map<String, dynamic>? ?? {};

    return PaginatedResult<LeadItem>(
      items: items,
      total: (metadata['total'] as num?)?.toInt() ?? items.length,
      page: (metadata['page'] as num?)?.toInt() ?? page,
      limit: (metadata['limit'] as num?)?.toInt() ?? limit,
      totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
      hasMore: (metadata['hasMore'] as bool?) ?? false,
    );
  }

  PaginatedResult<LeadItem> _parseLeadsPage(
    String raw,
    int page,
    int limit,
  ) {
    final decoded = jsonDecode(raw);
    // Handle legacy cache format (plain array, no wrapper)
    if (decoded is List) {
      final items = decoded
          .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return PaginatedResult<LeadItem>(
        items: items,
        total: items.length,
        page: page,
        limit: limit,
        totalPages: 1,
        hasMore: false,
      );
    }
    final result = decoded as Map<String, dynamic>;
    final data = result['data'];
    final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

    final items = data is List<dynamic>
        ? data
            .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
            .toList()
        : <LeadItem>[];

    return PaginatedResult<LeadItem>(
      items: items,
      total: (metadata['total'] as num?)?.toInt() ?? items.length,
      page: (metadata['page'] as num?)?.toInt() ?? page,
      limit: (metadata['limit'] as num?)?.toInt() ?? limit,
      totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
      hasMore: (metadata['hasMore'] as bool?) ?? false,
    );
  }

  /// GET /leads/:id
  Future<LeadItem> getLead(String id, {bool forceRefresh = false}) async {
    final cacheKey = 'lead_$id';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return LeadItem.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/leads/$id');
    final data = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, data, ttlSeconds: _cacheTtlSeconds);
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /leads
  Future<LeadItem> createLead(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/leads', data);
    CacheService.instance.invalidate('lead*');
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /leads/:id
  Future<LeadItem> updateLead(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.put('/leads/$id', data);
    CacheService.instance.invalidate('lead*');
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PATCH /leads/:id/stage — move a lead to a new pipeline stage.
  Future<LeadItem> updateLeadStage(
    String id,
    LeadStage newStage,
  ) async {
    final result = await ApiService.instance.patch(
      '/leads/$id/stage',
      {'stage': newStage.name},
    );
    CacheService.instance.invalidate('lead*');
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /leads/:id
  Future<void> deleteLead(String id) async {
    await ApiService.instance.delete('/leads/$id');
    CacheService.instance.invalidate('lead*');
  }

  /// Read the access token from storage for direct HTTP calls.
  Future<String> _getAccessToken() async {
    final tokens = await readAuthTokens();
    return tokens.accessToken ?? '';
  }
}
