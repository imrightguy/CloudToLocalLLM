import 'dart:convert';

import '../models.dart';
import 'api_service.dart';
import 'cache_service.dart';

class EmployeeService {
  EmployeeService._();
  static final EmployeeService instance = EmployeeService._();

  static const int _cacheTtlSeconds = 300;

  Future<List<EmployeeItem>> getEmployees({
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'employees_${search ?? '_'}';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return _parseEmployeesList(cached);
      }
    }

    String path = '/employees';
    if (search != null && search.isNotEmpty) {
      path += '?search=${Uri.encodeComponent(search)}';
    }
    final result = await ApiService.instance.get(path);
    final raw = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, raw, ttlSeconds: _cacheTtlSeconds);
    return _parseEmployeesList(raw);
  }

  List<EmployeeItem> _parseEmployeesList(String raw) {
    final data = jsonDecode(raw);
    if (data is List) {
      return data
          .map((e) => EmployeeItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [EmployeeItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<EmployeeItem> getEmployee(String id,
      {bool forceRefresh = false}) async {
    final cacheKey = 'employee_$id';
    if (!forceRefresh) {
      final cached = CacheService.instance.get(cacheKey);
      if (cached != null) {
        return EmployeeItem.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
    }

    final result = await ApiService.instance.get('/employees/$id');
    final data = jsonEncode(result['data']);
    CacheService.instance.set(cacheKey, data, ttlSeconds: _cacheTtlSeconds);
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<EmployeeItem> createEmployee(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/employees', data);
    CacheService.instance.invalidate('employee*');
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<EmployeeItem> updateEmployee(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.patch('/employees/$id', data);
    CacheService.instance.invalidate('employee*');
    return EmployeeItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<void> deleteEmployee(String id) async {
    await ApiService.instance.delete('/employees/$id');
    CacheService.instance.invalidate('employee*');
  }
}
