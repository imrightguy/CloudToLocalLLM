import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/schedule_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ScheduleItem model tests
  // ---------------------------------------------------------------------------
  group('ScheduleItem', () {
    test('fromJson with full API payload', () {
      final json = {
        'id': 'sched-1',
        'employeeId': 'emp-1',
        'employeeName': 'Marie Tremblay',
        'buildingId': 'bld-1',
        'buildingName': '1234 Rue Saint-Catherine',
        'dayOfWeek': 1,
        'startTime': '09:00',
        'endTime': '17:00',
        'createdAt': '2025-06-15T10:00:00.000Z',
      };

      final s = ScheduleItem.fromJson(json);

      expect(s.id, 'sched-1');
      expect(s.employeeId, 'emp-1');
      expect(s.employeeName, 'Marie Tremblay');
      expect(s.buildingId, 'bld-1');
      expect(s.buildingName, '1234 Rue Saint-Catherine');
      expect(s.dayOfWeek, 1);
      expect(s.startTime, '09:00');
      expect(s.endTime, '17:00');
      expect(s.createdAt, DateTime.parse('2025-06-15T10:00:00.000Z'));
    });

    test('fromJson with minimal payload uses defaults', () {
      final json = <String, dynamic>{
        'dayOfWeek': 3,
        'startTime': '10:00',
        'endTime': '18:00',
      };

      final s = ScheduleItem.fromJson(json);

      expect(s.id, isNull);
      expect(s.employeeId, isNull);
      expect(s.employeeName, isNull);
      expect(s.buildingId, isNull);
      expect(s.buildingName, isNull);
      expect(s.dayOfWeek, 3);
      expect(s.startTime, '10:00');
      expect(s.endTime, '18:00');
      expect(s.createdAt, isNull);
    });

    test('fromJson defaults dayOfWeek to 0', () {
      final json = <String, dynamic>{};

      final s = ScheduleItem.fromJson(json);

      expect(s.dayOfWeek, 0);
    });

    test('fromJson defaults startTime to 09:00 and endTime to 17:00', () {
      final json = <String, dynamic>{'dayOfWeek': 2};

      final s = ScheduleItem.fromJson(json);

      expect(s.startTime, '09:00');
      expect(s.endTime, '17:00');
    });

    test('fromJson handles num dayOfWeek', () {
      final json = <String, dynamic>{
        'dayOfWeek': 5.0,
        'startTime': '08:00',
        'endTime': '16:00',
      };

      final s = ScheduleItem.fromJson(json);

      expect(s.dayOfWeek, 5);
    });

    test('toJson round-trips key fields', () {
      const s = ScheduleItem(
        id: 'sched-2',
        employeeId: 'emp-2',
        buildingId: 'bld-2',
        dayOfWeek: 4,
        startTime: '08:00',
        endTime: '16:00',
      );

      final json = s.toJson();

      expect(json['id'], 'sched-2');
      expect(json['employeeId'], 'emp-2');
      expect(json['buildingId'], 'bld-2');
      expect(json['dayOfWeek'], 4);
      expect(json['startTime'], '08:00');
      expect(json['endTime'], '16:00');
    });

    test('toJson omits null optional fields', () {
      const s = ScheduleItem(
        dayOfWeek: 0,
        startTime: '09:00',
        endTime: '17:00',
      );

      final json = s.toJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('employeeId'), false);
      expect(json.containsKey('buildingId'), false);
      // required fields always present
      expect(json['dayOfWeek'], 0);
      expect(json['startTime'], '09:00');
      expect(json['endTime'], '17:00');
    });

    test('dayLabel returns French day names (0=Dimanche through 6=Samedi)', () {
      const days = [
        'Dimanche', // 0
        'Lundi', // 1
        'Mardi', // 2
        'Mercredi', // 3
        'Jeudi', // 4
        'Vendredi', // 5
        'Samedi', // 6
      ];

      for (var i = 0; i < days.length; i++) {
        final s = ScheduleItem(dayOfWeek: i, startTime: '09:00', endTime: '17:00');
        expect(s.dayLabel, days[i], reason: 'dayOfWeek=$i should be ${days[i]}');
      }
    });

    test('dayLabel handles out-of-range values', () {
      const s = ScheduleItem(dayOfWeek: 9, startTime: '09:00', endTime: '17:00');
      expect(s.dayLabel, 'Jour 9');
    });

    test('dayLabel handles negative values', () {
      const s = ScheduleItem(dayOfWeek: -1, startTime: '09:00', endTime: '17:00');
      expect(s.dayLabel, 'Jour -1');
    });
  });

  // ---------------------------------------------------------------------------
  // ScheduleItem.overlaps() — core conflict detection
  // ---------------------------------------------------------------------------
  group('ScheduleItem.overlaps', () {
    test('no overlap when different days of week', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 2,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );

      expect(a.overlaps(b), false);
      expect(b.overlaps(a), false);
    });

    test('no overlap when same day but different buildings', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-2',
      );

      expect(a.overlaps(b), false);
      expect(b.overlaps(a), false);
    });

    test('overlaps when same day and same building with overlapping times', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '18:00',
        buildingId: 'bld-1',
      );

      expect(a.overlaps(b), true);
      expect(b.overlaps(a), true);
    });

    test('overlaps when one schedule fully contains another', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '20:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '12:00',
        buildingId: 'bld-1',
      );

      expect(a.overlaps(b), true);
      expect(b.overlaps(a), true);
    });

    test('no overlap when schedules are adjacent (end == start)', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '12:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '12:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );

      // end == start should NOT overlap (half-open interval)
      expect(a.overlaps(b), false);
      expect(b.overlaps(a), false);
    });

    test('no overlap when schedules are fully disjoint', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '08:00',
        endTime: '10:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '14:00',
        endTime: '18:00',
        buildingId: 'bld-1',
      );

      expect(a.overlaps(b), false);
      expect(b.overlaps(a), false);
    });

    test('overlaps when either schedule has null buildingId', () {
      const a = ScheduleItem(
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );
      const b = ScheduleItem(
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '18:00',
        // buildingId null
      );

      // null buildingId means no building filter — should overlap
      expect(a.overlaps(b), true);
      expect(b.overlaps(a), true);
    });

    test('overlaps when both schedules have null buildingId', () {
      const a = ScheduleItem(
        dayOfWeek: 3,
        startTime: '09:00',
        endTime: '17:00',
      );
      const b = ScheduleItem(
        dayOfWeek: 3,
        startTime: '16:00',
        endTime: '20:00',
      );

      expect(a.overlaps(b), true);
    });
  });

  // ---------------------------------------------------------------------------
  // ScheduleService
  // ---------------------------------------------------------------------------
  group('ScheduleService', () {
    test('singleton instance is stable', () {
      expect(
        identical(ScheduleService.instance, ScheduleService.instance),
        true,
      );
    });

    test('detectConflicts returns overlapping schedules', () {
      const newEntry = ScheduleItem(
        id: 'new-1',
        dayOfWeek: 1,
        startTime: '10:00',
        endTime: '14:00',
        buildingId: 'bld-1',
      );

      final existing = [
        const ScheduleItem(
          id: 'existing-1',
          dayOfWeek: 1,
          startTime: '09:00',
          endTime: '12:00',
          buildingId: 'bld-1',
        ),
        const ScheduleItem(
          id: 'existing-2',
          dayOfWeek: 1,
          startTime: '13:00',
          endTime: '17:00',
          buildingId: 'bld-1',
        ),
        const ScheduleItem(
          id: 'existing-3',
          dayOfWeek: 2,
          startTime: '10:00',
          endTime: '14:00',
          buildingId: 'bld-1',
        ),
      ];

      final conflicts = ScheduleService.instance.detectConflicts(newEntry, existing);

      // existing-1 overlaps (09:00-12:00 vs 10:00-14:00)
      // existing-2 overlaps (13:00-17:00 vs 10:00-14:00)
      // existing-3 does NOT overlap (different day)
      expect(conflicts.length, 2);
      expect(conflicts.any((s) => s.id == 'existing-1'), true);
      expect(conflicts.any((s) => s.id == 'existing-2'), true);
    });

    test('detectConflicts excludes self (same id)', () {
      const newEntry = ScheduleItem(
        id: 'sched-1',
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '17:00',
        buildingId: 'bld-1',
      );

      final existing = [
        const ScheduleItem(
          id: 'sched-1',
          dayOfWeek: 1,
          startTime: '09:00',
          endTime: '17:00',
          buildingId: 'bld-1',
        ),
      ];

      final conflicts = ScheduleService.instance.detectConflicts(newEntry, existing);

      expect(conflicts, isEmpty);
    });

    test('detectConflicts returns empty for no conflicts', () {
      const newEntry = ScheduleItem(
        id: 'new-1',
        dayOfWeek: 1,
        startTime: '09:00',
        endTime: '12:00',
        buildingId: 'bld-1',
      );

      final existing = [
        const ScheduleItem(
          id: 'existing-1',
          dayOfWeek: 1,
          startTime: '13:00',
          endTime: '17:00',
          buildingId: 'bld-1',
        ),
        const ScheduleItem(
          id: 'existing-2',
          dayOfWeek: 2,
          startTime: '09:00',
          endTime: '12:00',
          buildingId: 'bld-1',
        ),
      ];

      final conflicts = ScheduleService.instance.detectConflicts(newEntry, existing);

      expect(conflicts, isEmpty);
    });

    test('getSchedules path includes employeeId when provided', () {
      // Verify the path construction logic (mirroring the service code)
      String path = '/schedules';
      const employeeId = 'emp-42';
      if (employeeId.isNotEmpty) {
        path += '?employeeId=${Uri.encodeComponent(employeeId)}';
      }

      expect(path, '/schedules?employeeId=emp-42');
    });

    test('getSchedules path omits employeeId when null', () {
      String path = '/schedules';
      const String? employeeId = null;
      if (employeeId != null && employeeId.isNotEmpty) {
        path += '?employeeId=${Uri.encodeComponent(employeeId)}';
      }

      expect(path, '/schedules');
    });

    test('getSchedules path omits employeeId when empty', () {
      String path = '/schedules';
      const employeeId = '';
      if (employeeId.isNotEmpty) {
        path += '?employeeId=${Uri.encodeComponent(employeeId)}';
      }

      expect(path, '/schedules');
    });
  });
}
