import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/employee_service.dart';
import 'package:immogestion/services/schedule_service.dart';

void main() {
  group('EmployeeItem', () {
    test('fromJson parses all fields', () {
      final employee = EmployeeItem.fromJson({
        'id': 'e1',
        'firstName': 'Jean',
        'lastName': 'Dupont',
        'email': 'jean@test.com',
        'phone': '514-555-1234',
        'isActive': true,
        'createdAt': '2024-01-15T10:00:00.000',
        'buildingAssignments': [
          {
            'id': 'ba1',
            'buildingId': 'b1',
            'buildingName': 'Le Saint-Laurent',
            'role': 'primary',
          },
        ],
      });
      expect(employee.id, 'e1');
      expect(employee.fullName, 'Jean Dupont');
      expect(employee.email, 'jean@test.com');
      expect(employee.phone, '514-555-1234');
      expect(employee.isActive, isTrue);
      expect(employee.buildingAssignments.length, 1);
      expect(employee.buildingAssignments.first.buildingName, 'Le Saint-Laurent');
    });

    test('fromJson defaults missing fields', () {
      final employee = EmployeeItem.fromJson({});
      expect(employee.id, isNull);
      expect(employee.fullName, 'Employé');
      expect(employee.firstName, '');
      expect(employee.lastName, '');
      expect(employee.email, '');
      expect(employee.phone, '');
      expect(employee.isActive, isTrue);
      expect(employee.buildingAssignments, isEmpty);
    });

    test('fullName returns firstName + lastName', () {
      final employee = EmployeeItem.fromJson({
        'firstName': 'Marie',
        'lastName': 'Tremblay',
      });
      expect(employee.fullName, 'Marie Tremblay');
    });

    test('fullName returns fallback when empty', () {
      const employee = EmployeeItem(firstName: '', lastName: '', email: '', phone: '', isActive: true, buildingAssignments: []);
      expect(employee.fullName, 'Employé');
    });

    test('toJson round-trips', () {
      const original = EmployeeItem(
        id: 'e1',
        firstName: 'Jean',
        lastName: 'Dupont',
        email: 'jean@test.com',
        phone: '514-555-1234',
        isActive: false,
        buildingAssignments: [
          BuildingAssignment(id: 'ba1', buildingId: 'b1', buildingName: 'Test', role: 'backup'),
        ],
      );
      final json = original.toJson();
      final restored = EmployeeItem.fromJson(json);
      expect(restored.id, 'e1');
      expect(restored.fullName, 'Jean Dupont');
      expect(restored.isActive, isFalse);
      expect(restored.buildingAssignments.length, 1);
      expect(restored.buildingAssignments.first.role, 'backup');
    });

    test('toJson omits null optional fields', () {
      const employee = EmployeeItem(firstName: 'J', lastName: 'D', email: 'j@d.com', phone: '', isActive: true, buildingAssignments: []);
      final json = employee.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });
  });

  group('BuildingAssignment', () {
    test('fromJson parses all fields', () {
      final assignment = BuildingAssignment.fromJson({
        'id': 'ba1',
        'buildingId': 'b1',
        'buildingName': 'Le Plateau',
        'role': 'backup',
      });
      expect(assignment.id, 'ba1');
      expect(assignment.buildingId, 'b1');
      expect(assignment.buildingName, 'Le Plateau');
      expect(assignment.role, 'backup');
    });

    test('roleLabel returns French labels', () {
      const primary = BuildingAssignment(role: 'primary');
      expect(primary.roleLabel, 'Principale');

      const backup = BuildingAssignment(role: 'backup');
      expect(backup.roleLabel, 'Remplacement');

      const other = BuildingAssignment(role: 'custom');
      expect(other.roleLabel, 'custom');
    });

    test('fromJson defaults', () {
      final assignment = BuildingAssignment.fromJson({});
      expect(assignment.id, isNull);
      expect(assignment.buildingId, isNull);
      expect(assignment.buildingName, isNull);
      expect(assignment.role, 'primary');
    });
  });

  group('ScheduleItem', () {
    test('fromJson parses all fields', () {
      final schedule = ScheduleItem.fromJson({
        'id': 's1',
        'employeeId': 'e1',
        'employeeName': 'Jean Dupont',
        'buildingId': 'b1',
        'buildingName': 'Le Saint-Laurent',
        'dayOfWeek': 1,
        'startTime': '09:00',
        'endTime': '17:00',
        'createdAt': '2024-01-15T10:00:00.000',
      });
      expect(schedule.id, 's1');
      expect(schedule.employeeId, 'e1');
      expect(schedule.employeeName, 'Jean Dupont');
      expect(schedule.buildingId, 'b1');
      expect(schedule.buildingName, 'Le Saint-Laurent');
      expect(schedule.dayOfWeek, 1);
      expect(schedule.startTime, '09:00');
      expect(schedule.endTime, '17:00');
      expect(schedule.dayLabel, 'Lundi');
    });

    test('fromJson defaults missing fields', () {
      final schedule = ScheduleItem.fromJson({});
      expect(schedule.id, isNull);
      expect(schedule.dayOfWeek, 0);
      expect(schedule.startTime, '09:00');
      expect(schedule.endTime, '17:00');
      expect(schedule.dayLabel, 'Dimanche');
    });

    test('dayLabel returns correct French day names', () {
      expect(const ScheduleItem(dayOfWeek: 0, startTime: '', endTime: '').dayLabel, 'Dimanche');
      expect(const ScheduleItem(dayOfWeek: 1, startTime: '', endTime: '').dayLabel, 'Lundi');
      expect(const ScheduleItem(dayOfWeek: 2, startTime: '', endTime: '').dayLabel, 'Mardi');
      expect(const ScheduleItem(dayOfWeek: 3, startTime: '', endTime: '').dayLabel, 'Mercredi');
      expect(const ScheduleItem(dayOfWeek: 4, startTime: '', endTime: '').dayLabel, 'Jeudi');
      expect(const ScheduleItem(dayOfWeek: 5, startTime: '', endTime: '').dayLabel, 'Vendredi');
      expect(const ScheduleItem(dayOfWeek: 6, startTime: '', endTime: '').dayLabel, 'Samedi');
    });

    test('toJson round-trips', () {
      const original = ScheduleItem(
        id: 's1',
        employeeId: 'e1',
        buildingId: 'b1',
        dayOfWeek: 3,
        startTime: '10:00',
        endTime: '18:00',
      );
      final json = original.toJson();
      final restored = ScheduleItem.fromJson(json);
      expect(restored.id, 's1');
      expect(restored.dayOfWeek, 3);
      expect(restored.startTime, '10:00');
      expect(restored.endTime, '18:00');
    });

    test('overlaps detects time conflicts on same day', () {
      const a = ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '09:00', endTime: '12:00');
      const b = ScheduleItem(id: 's2', dayOfWeek: 1, startTime: '11:00', endTime: '14:00');
      expect(a.overlaps(b), isTrue);
    });

    test('overlaps returns false for different days', () {
      const a = ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      const b = ScheduleItem(id: 's2', dayOfWeek: 2, startTime: '09:00', endTime: '17:00');
      expect(a.overlaps(b), isFalse);
    });

    test('overlaps returns false for non-overlapping times on same day', () {
      const a = ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '09:00', endTime: '12:00');
      const b = ScheduleItem(id: 's2', dayOfWeek: 1, startTime: '13:00', endTime: '17:00');
      expect(a.overlaps(b), isFalse);
    });

    test('overlaps returns true for same id with overlapping time', () {
      const a = ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      expect(a.overlaps(a), isTrue);
    });

    test('overlaps considers same building', () {
      const a = ScheduleItem(id: 's1', buildingId: 'b1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      const b = ScheduleItem(id: 's2', buildingId: 'b2', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      expect(a.overlaps(b), isFalse);
    });

    test('overlaps when buildingId is null', () {
      const a = ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      const b = ScheduleItem(id: 's2', buildingId: 'b2', dayOfWeek: 1, startTime: '09:00', endTime: '17:00');
      expect(a.overlaps(b), isTrue);
    });
  });

  group('EmployeeService', () {
    test('singleton instance is stable', () {
      expect(
        identical(EmployeeService.instance, EmployeeService.instance),
        true,
      );
    });
  });

  group('ScheduleService', () {
    test('singleton instance is stable', () {
      expect(
        identical(ScheduleService.instance, ScheduleService.instance),
        true,
      );
    });

    test('detectConflicts finds overlapping schedules', () {
      const newEntry = ScheduleItem(id: 's_new', dayOfWeek: 1, startTime: '09:00', endTime: '12:00');
      final existing = [
        const ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '10:00', endTime: '14:00'),
        const ScheduleItem(id: 's2', dayOfWeek: 2, startTime: '09:00', endTime: '12:00'),
      ];
      final conflicts = ScheduleService.instance.detectConflicts(newEntry, existing);
      expect(conflicts.length, 1);
      expect(conflicts.first.id, 's1');
    });

    test('detectConflicts returns empty when no overlap', () {
      const newEntry = ScheduleItem(id: 's_new', dayOfWeek: 1, startTime: '09:00', endTime: '12:00');
      final existing = [
        const ScheduleItem(id: 's1', dayOfWeek: 1, startTime: '13:00', endTime: '17:00'),
        const ScheduleItem(id: 's2', dayOfWeek: 2, startTime: '09:00', endTime: '12:00'),
      ];
      final conflicts = ScheduleService.instance.detectConflicts(newEntry, existing);
      expect(conflicts, isEmpty);
    });
  });
}
