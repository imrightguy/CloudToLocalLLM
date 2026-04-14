import '../models.dart';
import 'api_service.dart';

class UnitService {
  UnitService._();
  static final UnitService instance = UnitService._();

  Future<List<UnitItem>> getUnitsByBuilding(String buildingId) async {
    final result =
        await ApiService.instance.get('/buildings/$buildingId/units');
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => UnitItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [UnitItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<UnitItem> getUnit(String unitId) async {
    final result = await ApiService.instance.get('/units/$unitId');
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<UnitItem> updateUnit(String unitId, Map<String, dynamic> data) async {
    final result = await ApiService.instance.put('/units/$unitId', data);
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<UnitItem> createUnit(
    String buildingId,
    Map<String, dynamic> data,
  ) async {
    final result =
        await ApiService.instance.post('/buildings/$buildingId/units', data);
    return UnitItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<void> deleteUnit(String unitId) async {
    await ApiService.instance.delete('/units/$unitId');
  }

  Future<List<BuildingItem>> getBuildings() async {
    final result = await ApiService.instance.get('/buildings');
    final data = result['data'] as List<dynamic>;
    return data
        .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
