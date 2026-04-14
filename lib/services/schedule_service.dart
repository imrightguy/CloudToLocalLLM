import '../models.dart';
import 'api_service.dart';

class ScheduleService {
  ScheduleService._();
  static final ScheduleService instance = ScheduleService._();

  Future<List<ScheduleItem>> getSchedules({String? employeeId}) async {
    String path = '/schedules';
    if (employeeId != null && employeeId.isNotEmpty) {
      path += '?employeeId=${Uri.encodeComponent(employeeId)}';
    }
    final result = await ApiService.instance.get(path);
    final data = result['data'];
    if (data is List) {
      return data
          .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [ScheduleItem.fromJson(data as Map<String, dynamic>)];
  }

  Future<ScheduleItem> createSchedule(Map<String, dynamic> data) async {
    final result = await ApiService.instance.post('/schedules', data);
    return ScheduleItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<ScheduleItem> updateSchedule(
    String id,
    Map<String, dynamic> data,
  ) async {
    final result = await ApiService.instance.patch('/schedules/$id', data);
    return ScheduleItem.fromJson(result['data'] as Map<String, dynamic>);
  }

  Future<void> deleteSchedule(String id) async {
    await ApiService.instance.delete('/schedules/$id');
  }

  List<ScheduleItem> detectConflicts(
    ScheduleItem newEntry,
    List<ScheduleItem> existing,
  ) {
    return existing.where((s) => s.overlaps(newEntry) && s.id != newEntry.id).toList();
  }
}
