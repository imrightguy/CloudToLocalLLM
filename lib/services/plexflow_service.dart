import 'api_service.dart';

/// Read-only API client for PlexFlow property data exposed by the backend.
///
/// The backend proxies and caches PlexFlow (TTL 1h). When PlexFlow is not
/// configured the endpoints return empty lists rather than errors.
class PlexFlowService {
  PlexFlowService._();
  static final PlexFlowService instance = PlexFlowService._();

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final result = await ApiService.instance.get(path);
    final data = result['data'] as List<dynamic>? ?? const [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  /// GET /plexflow/buildings
  Future<List<Map<String, dynamic>>> getBuildings() =>
      _getList('/plexflow/buildings');

  /// GET /plexflow/buildings/:id/units
  Future<List<Map<String, dynamic>>> getUnits(String buildingId) =>
      _getList('/plexflow/buildings/$buildingId/units');

  /// GET /plexflow/units/:id/leases
  Future<List<Map<String, dynamic>>> getLeases(String unitId) =>
      _getList('/plexflow/units/$unitId/leases');

  /// GET /plexflow/units/:id/tenants
  Future<List<Map<String, dynamic>>> getTenants(String unitId) =>
      _getList('/plexflow/units/$unitId/tenants');

  /// POST /plexflow/sync — trigger a manual synchronization.
  Future<Map<String, dynamic>> sync() async {
    final result = await ApiService.instance.post('/plexflow/sync', null);
    return (result['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// GET /plexflow/buildings/:id/gap-analysis
  ///
  /// Compare le snapshot PlexFlow d'un bâtiment avec la DB locale et retourne
  /// les unités/baux/locataires manquants ainsi que les enregistrements en trop.
  Future<Map<String, dynamic>> getGapAnalysis(String buildingId) async {
    final result =
        await ApiService.instance.get('/plexflow/buildings/$buildingId/gap-analysis');
    return (result['data'] as Map<String, dynamic>?) ?? const {};
  }

  /// POST /plexflow/buildings/:id/ingest
  ///
  /// Crée localement les données PlexFlow manquantes du bâtiment et retourne le
  /// rapport d'ingestion (créations, mises à jour, erreurs).
  Future<Map<String, dynamic>> ingestMissing(String buildingId) async {
    final result = await ApiService.instance
        .post('/plexflow/buildings/$buildingId/ingest', null);
    return (result['data'] as Map<String, dynamic>?) ?? const {};
  }
}
