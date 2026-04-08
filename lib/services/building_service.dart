import '../models.dart';
import 'api_service.dart';

/// Paginated result wrapper matching the API metadata envelope.
class PaginatedResult<T> {
  const PaginatedResult({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
    required this.hasMore,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;
  final bool hasMore;
}

/// Service for building and unit CRUD operations.
///
/// All methods throw [ApiException] on failure.
class BuildingService {
  BuildingService._();
  static final BuildingService instance = BuildingService._();

  // ---------------------------------------------------------------------------
  // Buildings
  // ---------------------------------------------------------------------------

  /// GET /buildings?search=…&page=…&limit=…
  Future<PaginatedResult<BuildingItem>> getBuildings({
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    final result = await ApiService.instance.get('/buildings?$query');

    final data = result['data'];
    final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

    final items = (data as List<dynamic>)
        .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return PaginatedResult<BuildingItem>(
      items: items,
      total: (metadata['total'] as num?)?.toInt() ?? items.length,
      page: (metadata['page'] as num?)?.toInt() ?? page,
      limit: (metadata['limit'] as num?)?.toInt() ?? limit,
      totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
      hasMore: (metadata['hasMore'] as bool?) ?? false,
    );
  }

  /// GET /buildings/:id
  Future<BuildingItem> getBuilding(String id) async {
    final result = await ApiService.instance.get('/buildings/$id');
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /buildings
  Future<BuildingItem> createBuilding(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/buildings', data);
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /buildings/:id
  Future<BuildingItem> updateBuilding(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.put('/buildings/$id', data);
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /buildings/:id
  Future<void> deleteBuilding(String id) async {
    await ApiService.instance.delete('/buildings/$id');
  }

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  /// GET /buildings/:buildingId/units
  Future<List<UnitItem>> getUnits(String buildingId) async {
    final result =
        await ApiService.instance.get('/buildings/$buildingId/units');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Single-object fallback
    return [UnitItem.fromJson(data as Map<String, dynamic>)];
  }

  /// POST /buildings/:buildingId/units
  Future<UnitItem> createUnit(
    String buildingId,
    Map<String, dynamic> data,
  ) async {
    final result =
        await ApiService.instance.post('/buildings/$buildingId/units', data);
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /units/:id
  Future<UnitItem> updateUnit(String id, Map<String, dynamic> data) async {
    final result = await ApiService.instance.put('/units/$id', data);
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /units/:id
  Future<void> deleteUnit(String id) async {
    await ApiService.instance.delete('/units/$id');
  }
}
