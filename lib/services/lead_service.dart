import '../models.dart';
import 'api_service.dart';
import 'building_service.dart';

/// Service for lead CRUD and pipeline stage management.
///
/// All methods throw [ApiException] on failure.
class LeadService {
  LeadService._();
  static final LeadService instance = LeadService._();

  // ---------------------------------------------------------------------------
  // Leads
  // ---------------------------------------------------------------------------

  /// GET /leads?stage=…&search=…&page=…&limit=…
  Future<PaginatedResult<LeadItem>> getLeads({
    LeadStage? stage,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (stage != null) params['stage'] = stage.name;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final result = await ApiService.instance.get('/leads?$query');

    final data = result['data'];
    final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

    final items = (data as List<dynamic>)
        .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
        .toList();

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
  Future<LeadItem> getLead(String id) async {
    final result = await ApiService.instance.get('/leads/$id');
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /leads
  Future<LeadItem> createLead(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/leads', data);
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /leads/:id
  Future<LeadItem> updateLead(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.put('/leads/$id', data);
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
    return LeadItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /leads/:id
  Future<void> deleteLead(String id) async {
    await ApiService.instance.delete('/leads/$id');
  }
}
