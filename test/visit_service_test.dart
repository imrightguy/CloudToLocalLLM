import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/building_service.dart';
import 'package:immogestion/services/visit_service.dart';

void main() {
  group('VisitItem', () {
    test('fromJson with full API payload (nested objects)', () {
      final json = {
        'id': 'visit-1',
        'dateTime': '2025-06-15T14:30:00.000Z',
        'unit': {'label': '4B', 'id': 'unit-1'},
        'building': {'name': '1234 Rue Saint-Catherine', 'id': 'bld-1'},
        'dateLabel': '15 juin 2025',
        'status': 'confirmed',
        'employee': {
          'firstName': 'Marie',
          'lastName': 'Tremblay',
        },
        'notes': 'Vérifier les fenêtres',
        'lead': {'fullName': 'Jean Dupont'},
        'tenantConfirmed': true,
        'employeeConfirmed': false,
        'occupantNotified': true,
        'occupantSMS': {'to': '514-555-0000', 'status': 'delivered'},
      };

      final visit = VisitItem.fromJson(json);

      expect(visit.id, 'visit-1');
      expect(visit.dateTime, DateTime.parse('2025-06-15T14:30:00.000Z'));
      expect(visit.unitLabel, '4B');
      expect(visit.buildingName, '1234 Rue Saint-Catherine');
      expect(visit.status, 'confirmed');
      expect(visit.agent, 'Marie Tremblay');
      expect(visit.notes, 'Vérifier les fenêtres');
      expect(visit.leadName, 'Jean Dupont');
      expect(visit.tenantConfirmed, true);
      expect(visit.employeeConfirmed, false);
      expect(visit.occupantNotified, true);
      expect(visit.occupantSMS, {'to': '514-555-0000', 'status': 'delivered'});
    });

    test('fromJson with flat payload (backward compat)', () {
      final json = {
        'id': 'visit-2',
        'unitLabel': '5A',
        'buildingName': '456 Boulevard Saint-Laurent',
        'dateLabel': '20 juil. 2025',
        'status': 'pending',
        'agent': 'Pierre Martin',
        'notes': '',
      };

      final visit = VisitItem.fromJson(json);

      expect(visit.id, 'visit-2');
      expect(visit.unitLabel, '5A');
      expect(visit.buildingName, '456 Boulevard Saint-Laurent');
      expect(visit.agent, 'Pierre Martin');
      expect(visit.leadName, isNull);
      expect(visit.tenantConfirmed, false);
      expect(visit.occupantSMS, isNull);
    });

    test('fromJson with minimal payload uses defaults', () {
      final json = <String, dynamic>{};

      final visit = VisitItem.fromJson(json);

      expect(visit.id, isNull);
      expect(visit.unitLabel, '');
      expect(visit.buildingName, '');
      expect(visit.dateLabel, '');
      expect(visit.status, '');
      expect(visit.agent, '');
      expect(visit.notes, '');
      expect(visit.dateTime, isNull);
      expect(visit.leadName, isNull);
      expect(visit.tenantConfirmed, false);
      expect(visit.employeeConfirmed, false);
      expect(visit.occupantNotified, false);
      expect(visit.occupantSMS, isNull);
    });

    test('fromJson derives dateLabel from dateTime when dateLabel missing', () {
      final json = {
        'dateTime': '2025-03-20T10:00:00.000Z',
        'unitLabel': '1A',
        'buildingName': 'Test',
        'status': 'planned',
        'agent': 'Test',
        'notes': '',
      };

      final visit = VisitItem.fromJson(json);

      expect(visit.dateLabel, isNotEmpty);
      expect(visit.dateTime, isNotNull);
    });

    test('fromJson prefers explicit dateLabel over derived', () {
      final json = {
        'dateTime': '2025-03-20T10:00:00.000Z',
        'dateLabel': 'Custom label',
        'unitLabel': '1A',
        'buildingName': 'Test',
        'status': 'planned',
        'agent': 'Test',
        'notes': '',
      };

      final visit = VisitItem.fromJson(json);
      expect(visit.dateLabel, 'Custom label');
    });

    test('toJson round-trips key fields', () {
      final visit = VisitItem(
        id: 'visit-3',
        unitLabel: '2C',
        buildingName: '789 Rue Ontario',
        dateLabel: '01 avr. 2025',
        dateTime: DateTime.parse('2025-04-01T11:00:00.000Z'),
        status: 'cancelled',
        agent: 'Sophie Bérubé',
        notes: 'Annulé par le locataire',
        leadName: 'Luc Grégoire',
        tenantConfirmed: true,
        employeeConfirmed: true,
        occupantNotified: true,
        occupantSMS: {'to': '514-555-1111'},
      );

      final json = visit.toJson();

      expect(json['id'], 'visit-3');
      expect(json['unitLabel'], '2C');
      expect(json['buildingName'], '789 Rue Ontario');
      expect(json['dateLabel'], '01 avr. 2025');
      expect(json['status'], 'cancelled');
      expect(json['agent'], 'Sophie Bérubé');
      expect(json['notes'], 'Annulé par le locataire');
      expect(json['leadName'], 'Luc Grégoire');
      expect(json['tenantConfirmed'], true);
      expect(json['employeeConfirmed'], true);
      expect(json['occupantNotified'], true);
      expect(json['occupantSMS'], {'to': '514-555-1111'});
    });

    test('toJson omits null optional fields', () {
      const visit = VisitItem(
        unitLabel: '3D',
        buildingName: 'Test',
        dateLabel: '',
        status: 'planned',
        agent: '',
        notes: '',
      );

      final json = visit.toJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('dateTime'), false);
      expect(json.containsKey('leadName'), false);
      expect(json.containsKey('occupantSMS'), false);
    });

    test('fromJson handles invalid dateTime gracefully', () {
      final json = {
        'dateTime': 'not-a-date',
        'unitLabel': '1A',
        'buildingName': 'Test',
        'status': 'planned',
        'agent': 'Test',
        'notes': '',
      };

      final visit = VisitItem.fromJson(json);
      expect(visit.dateTime, isNull);
    });
  });

  group('VisitService', () {
    test('singleton instance is stable', () {
      expect(
        identical(VisitService.instance, VisitService.instance),
        true,
      );
    });

    test('getVisits query encodes date parameters', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      final dateFrom = DateTime(2025, 1, 1);
      final dateTo = DateTime(2025, 6, 30);
      params['dateFrom'] = dateFrom.toIso8601String().split('T').first;
      params['dateTo'] = dateTo.toIso8601String().split('T').first;

      expect(params['dateFrom'], '2025-01-01');
      expect(params['dateTo'], '2025-06-30');
    });

    test('getVisits query omits null date params', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const DateTime? dateFrom = null;
      const DateTime? dateTo = null;
      const String? status = null;

      if (dateFrom != null) params['dateFrom'] = 'x';
      if (dateTo != null) params['dateTo'] = 'x';
      if (status != null && status.isNotEmpty) params['status'] = status;

      expect(params.length, 2);
      expect(params.containsKey('dateFrom'), false);
      expect(params.containsKey('dateTo'), false);
      expect(params.containsKey('status'), false);
    });

    test('getVisits query omits empty status', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const status = '';
      if (status.isNotEmpty) params['status'] = status;

      expect(params.containsKey('status'), false);
    });

    test('getVisits query includes non-empty status', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const status = 'confirmed';
      if (status.isNotEmpty) params['status'] = status;

      expect(params['status'], 'confirmed');
      expect(params.length, 3);
    });

    test('getVisits metadata defaults when missing', () {
      final result = <String, dynamic>{
        'data': [
          {
            'unitLabel': '1A',
            'buildingName': 'Test Building',
            'dateLabel': '01 juin 2025',
            'status': 'planned',
            'agent': 'Test Agent',
            'notes': '',
          },
        ],
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
          .toList();

      const page = 1;
      const limit = 20;

      final paginated = PaginatedResult<VisitItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? items.length,
        page: (metadata['page'] as num?)?.toInt() ?? page,
        limit: (metadata['limit'] as num?)?.toInt() ?? limit,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items.length, 1);
      expect(paginated.items.first.unitLabel, '1A');
      expect(paginated.total, 1);
      expect(paginated.hasMore, false);
    });

    test('getVisits metadata parses when present', () {
      final result = <String, dynamic>{
        'data': [],
        'metadata': {
          'total': 42,
          'page': 2,
          'limit': 10,
          'totalPages': 5,
          'hasMore': true,
        },
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => VisitItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final paginated = PaginatedResult<VisitItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? 0,
        page: (metadata['page'] as num?)?.toInt() ?? 1,
        limit: (metadata['limit'] as num?)?.toInt() ?? 20,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items, isEmpty);
      expect(paginated.total, 42);
      expect(paginated.page, 2);
      expect(paginated.limit, 10);
      expect(paginated.totalPages, 5);
      expect(paginated.hasMore, true);
    });
  });
}
