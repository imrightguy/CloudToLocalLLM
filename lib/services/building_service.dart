import 'dart:convert';

import '../models.dart';
import 'api_service.dart';
import 'cache_service.dart';

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
/// Responses are cached for 5 minutes (stale-while-revalidate pattern).
class BuildingService {
  BuildingService._();
  static final BuildingService instance = BuildingService._();

  static const int _cacheTtlSeconds = 300;

  // ---------------------------------------------------------------------------
  // Buildings
  // ---------------------------------------------------------------------------

  /// GET /buildings?search=…&page=…&limit=…
  Future<PaginatedResult<BuildingItem>> getBuildings({
    String? search,
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'buildings_${search ?? ''}_p$page';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parseBuildingsPage(cached, page, limit);
      }
    }

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final result = await ApiService.instance.get('/buildings?$query');

    final raw = jsonEncode(result);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return _parseBuildingsPage(raw, page, limit);
  }

  PaginatedResult<BuildingItem> _parseBuildingsPage(
    String raw,
    int page,
    int limit,
  ) {
    final result = jsonDecode(raw) as Map<String, dynamic>;
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
  Future<BuildingItem> getBuilding(String id,
      {bool forceRefresh = false}) async {
    final cacheKey = 'building_$id';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return BuildingItem.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/buildings/$id');
    final data = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, data, ttlSeconds: _cacheTtlSeconds);
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// POST /buildings
  Future<BuildingItem> createBuilding(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/buildings', data);
    CacheService.instance.invalidate('building*');
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /buildings/:id
  Future<BuildingItem> updateBuilding(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.put('/buildings/$id', data);
    CacheService.instance.invalidate('building*');
    return BuildingItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /buildings/:id
  Future<void> deleteBuilding(String id) async {
    await ApiService.instance.delete('/buildings/$id');
    CacheService.instance.invalidate('building*');
  }

  // ---------------------------------------------------------------------------
  // Units
  // ---------------------------------------------------------------------------

  /// GET /buildings/units?buildingId=...
  Future<List<UnitItem>> getUnits(String buildingId,
      {bool forceRefresh = false}) async {
    final cacheKey = 'units_$buildingId';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parseUnitsList(cached);
      }
    }

    final result =
        await ApiService.instance.get('/buildings/units?buildingId=$buildingId');
    final raw = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return _parseUnitsList(raw);
  }

  List<UnitItem> _parseUnitsList(String raw) {
    final data = jsonDecode(raw);
    if (data is List) {
      return data
          .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [UnitItem.fromJson(data as Map<String, dynamic>)];
  }

  /// POST /buildings/units (buildingId in request body)
  Future<UnitItem> createUnit(
    String buildingId,
    Map<String, dynamic> data,
  ) async {
    final result =
        await ApiService.instance.post('/buildings/units', {'buildingId': buildingId, ...data});
    CacheService.instance.invalidate('unit*');
    CacheService.instance.invalidate('building*');
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// PUT /units/:id
  Future<UnitItem> updateUnit(String id, Map<String, dynamic> data) async {
    final result = await ApiService.instance.put('/buildings/units/$id', data);
    CacheService.instance.invalidate('unit*');
    CacheService.instance.invalidate('building*');
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  /// DELETE /units/:id
  Future<void> deleteUnit(String id) async {
    await ApiService.instance.delete('/buildings/units/$id');
    CacheService.instance.invalidate('unit*');
    CacheService.instance.invalidate('building*');
  }
}
