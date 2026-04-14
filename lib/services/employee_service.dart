import '../models.dart';
import 'api_service.dart';

class EmployeeService {
  EmployeeService._();
  static final EmployeeService instance = EmployeeService._();

  Future<List<EmployeeItem>> getEmployees({String? search}) async {
    String path = '/employees';
    if (search != null && search.isNotEmpty) {
      path += '?search=${Uri.encodeComponent(search)}';
    }
    final result = await ApiService.instance.get(path);
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => EmployeeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [EmployeeItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<EmployeeItem> getEmployee(String id) async {
    final result = await ApiService.instance.get('/employees/$id');
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<EmployeeItem> createEmployee(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/employees', data);
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<EmployeeItem> updateEmployee(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.patch('/employees/$id', data);
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(String id) async {
    await ApiService.instance.delete('/employees/$id');
  }
}
