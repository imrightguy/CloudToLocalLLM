import 'api_service.dart';

/// API client for departure / arrival (état des lieux) photos.
class DeparturePhotosService {
  DeparturePhotosService._();
  static final DeparturePhotosService instance = DeparturePhotosService._();

  /// GET /departure-photos — optionally filtered by building / unit / event type.
  Future<List<Map<String, dynamic>>> list({
    String? buildingId,
    String? unitId,
    String? eventType,
    int page = 1,
    int limit = 100,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (buildingId != null) params['buildingId'] = buildingId;
    if (unitId != null) params['unitId'] = unitId;
    if (eventType != null) params['eventType'] = eventType;

    final query =
        params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');

    final result = await ApiService.instance.get('/departure-photos?$query');
    final data = result['data'] as List<dynamic>? ?? const [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// DELETE /departure-photos/:id
  Future<void> delete(String id) async {
    await ApiService.instance.delete('/departure-photos/$id');
  }
}
