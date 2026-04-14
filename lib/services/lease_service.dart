import '../models.dart';
import 'api_service.dart';

class LeaseService {
  LeaseService._();
  static final LeaseService instance = LeaseService._();

  Future<List<LeaseItem>> getLeases({
    String? status,
    String? buildingId,
    String? unitId,
    String? search,
  }) async {
    final params = <String, String>{};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (buildingId != null && buildingId.isNotEmpty) params['buildingId'] = buildingId;
    if (unitId != null && unitId.isNotEmpty) params['unitId'] = unitId;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final path = query.isNotEmpty ? '/leases?$query' : '/leases';
    final result = await ApiService.instance.get(path);
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => LeaseItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [LeaseItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<LeaseItem> getLease(String id) async {
    final result = await ApiService.instance.get('/leases/$id');
    return LeaseItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<LeaseItem> getLeaseByBuilding(String buildingId) async {
    final result = await ApiService.instance.get('/leases/building/$buildingId');
    final data = result['data'];
    if (data is List) {
      return LeaseItem.fromJson(data.first as Map<String, dynamic>);
    }
    return LeaseItem.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaseItem> getLeaseByUnit(String unitId) async {
    final result = await ApiService.instance.get('/leases/unit/$unitId');
    final data = result['data'];
    if (data is List) {
      return LeaseItem.fromJson(data.first as Map<String, dynamic>);
    }
    return LeaseItem.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaseItem> createLease(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/leases', data);
    return LeaseItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<LeaseItem> updateLease(String id, Map<String, dynamic> data) async {
    final result = await ApiService.instance.patch('/leases/$id', data);
    return LeaseItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<LeaseItem> updateLeaseStatus(String id, String status) async {
    final result = await ApiService.instance.patch('/leases/$id/status', {'status': status});
    return LeaseItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<LeaseItem> signLease(String id) async {
    final result = await ApiService.instance.patch('/leases/$id/sign', {});
    return LeaseItem.fromJson(result['data'] as Map<String, dynamic>);
  }
}
