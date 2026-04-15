import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  group('LeaseStatus', () {
    test('fromString parses draft variants', () {
      expect(LeaseStatus.fromString('draft'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('Draft'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('brouillon'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('BROUILLON'), LeaseStatus.draft);
    });

    test('fromString parses sent variants', () {
      expect(LeaseStatus.fromString('sent'), LeaseStatus.sent);
      expect(LeaseStatus.fromString('envoyé'), LeaseStatus.sent);
      expect(LeaseStatus.fromString('envoye'), LeaseStatus.sent);
    });

    test('fromString parses signed variants', () {
      expect(LeaseStatus.fromString('signed'), LeaseStatus.signed);
      expect(LeaseStatus.fromString('signé'), LeaseStatus.signed);
      expect(LeaseStatus.fromString('signe'), LeaseStatus.signed);
    });

    test('fromString parses active variants', () {
      expect(LeaseStatus.fromString('active'), LeaseStatus.active);
      expect(LeaseStatus.fromString('actif'), LeaseStatus.active);
    });

    test('fromString parses terminated variants', () {
      expect(LeaseStatus.fromString('terminated'), LeaseStatus.terminated);
      expect(LeaseStatus.fromString('résilié'), LeaseStatus.terminated);
      expect(LeaseStatus.fromString('resilie'), LeaseStatus.terminated);
    });

    test('fromString defaults to draft for unknown values', () {
      expect(LeaseStatus.fromString('unknown'), LeaseStatus.draft);
      expect(LeaseStatus.fromString(''), LeaseStatus.draft);
      expect(LeaseStatus.fromString('foo'), LeaseStatus.draft);
    });

    test('labels are in French', () {
      expect(LeaseStatus.draft.label, 'Brouillon');
      expect(LeaseStatus.sent.label, 'Envoyé');
      expect(LeaseStatus.signed.label, 'Signé');
      expect(LeaseStatus.active.label, 'Actif');
      expect(LeaseStatus.terminated.label, 'Résilié');
    });

    test('apiValue returns lowercase English values', () {
      expect(LeaseStatus.draft.apiValue, 'draft');
      expect(LeaseStatus.sent.apiValue, 'sent');
      expect(LeaseStatus.signed.apiValue, 'signed');
      expect(LeaseStatus.active.apiValue, 'active');
      expect(LeaseStatus.terminated.apiValue, 'terminated');
    });

    test('all statuses have distinct colors', () {
      final colors = LeaseStatus.values.map((s) => s.color).toSet();
      expect(colors.length, LeaseStatus.values.length);
    });
  });

  group('LeaseItem', () {
    final sampleJson = {
      'id': 'lease-1',
      'buildingId': 'bldg-1',
      'buildingName': 'Édifice A',
      'unitId': 'unit-1',
      'unitLabel': '3A',
      'tenantName': 'Jean Dupont',
      'tenantEmail': 'jean@example.com',
      'tenantPhone': '(514) 555-1234',
      'startDate': '2026-01-01T00:00:00.000Z',
      'endDate': '2027-06-30T00:00:00.000Z',
      'monthlyRent': 120000,
      'deposit': 120000,
      'status': 'active',
      'notes': 'Renewal pending',
      'terms': 'Standard lease terms',
      'createdAt': '2025-12-01T00:00:00.000Z',
      'updatedAt': '2026-01-15T00:00:00.000Z',
    };

    test('fromJson parses all flat fields', () {
      final lease = LeaseItem.fromJson(sampleJson);
      expect(lease.id, 'lease-1');
      expect(lease.buildingId, 'bldg-1');
      expect(lease.buildingName, 'Édifice A');
      expect(lease.unitId, 'unit-1');
      expect(lease.unitLabel, '3A');
      expect(lease.tenantName, 'Jean Dupont');
      expect(lease.tenantEmail, 'jean@example.com');
      expect(lease.tenantPhone, '(514) 555-1234');
      expect(lease.monthlyRent, 120000);
      expect(lease.deposit, 120000);
      expect(lease.status, LeaseStatus.active);
      expect(lease.notes, 'Renewal pending');
      expect(lease.terms, 'Standard lease terms');
    });

    test('fromJson parses dates correctly', () {
      final lease = LeaseItem.fromJson(sampleJson);
      expect(lease.startDate, DateTime.parse('2026-01-01T00:00:00.000Z'));
      expect(lease.endDate, DateTime.parse('2027-06-30T00:00:00.000Z'));
      expect(lease.createdAt, DateTime.parse('2025-12-01T00:00:00.000Z'));
      expect(lease.updatedAt, DateTime.parse('2026-01-15T00:00:00.000Z'));
    });

    test('fromJson extracts buildingName from nested building object', () {
      final json = {
        ...sampleJson,
        'building': {'name': 'Tour B'},
      }..remove('buildingName');
      final lease = LeaseItem.fromJson(json);
      expect(lease.buildingName, 'Tour B');
    });

    test('fromJson extracts unitLabel from nested unit object', () {
      final json = {
        ...sampleJson,
        'unit': {'label': '5B'},
      }..remove('unitLabel');
      final lease = LeaseItem.fromJson(json);
      expect(lease.unitLabel, '5B');
    });

    test('fromJson extracts tenant fields from nested tenant object', () {
      final json = {
        ...sampleJson,
        'tenant': {
          'fullName': 'Marie Tremblay',
          'email': 'marie@example.com',
          'phone': '(514) 555-5678',
        },
      }..remove('tenantName')..remove('tenantEmail')..remove('tenantPhone');
      final lease = LeaseItem.fromJson(json);
      expect(lease.tenantName, 'Marie Tremblay');
      expect(lease.tenantEmail, 'marie@example.com');
      expect(lease.tenantPhone, '(514) 555-5678');
    });

    test('fromJson handles null dates gracefully', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..remove('startDate')
        ..remove('endDate')
        ..remove('createdAt')
        ..remove('updatedAt');
      final lease = LeaseItem.fromJson(json);
      expect(lease.startDate, isNull);
      expect(lease.endDate, isNull);
      expect(lease.createdAt, isNull);
      expect(lease.updatedAt, isNull);
    });

    test('fromJson handles invalid date strings gracefully', () {
      final json = Map<String, dynamic>.from(sampleJson)
        ..['startDate'] = 'not-a-date';
      final lease = LeaseItem.fromJson(json);
      expect(lease.startDate, isNull);
    });

    test('fromJson handles missing status', () {
      final json = Map<String, dynamic>.from(sampleJson)..remove('status');
      final lease = LeaseItem.fromJson(json);
      expect(lease.status, isNull);
      expect(lease.leaseStatus, LeaseStatus.draft);
    });

    test('fromJson handles all null optional fields', () {
      final lease = LeaseItem.fromJson({});
      expect(lease.id, isNull);
      expect(lease.buildingId, isNull);
      expect(lease.tenantName, isNull);
      expect(lease.monthlyRent, isNull);
      expect(lease.deposit, isNull);
      expect(lease.status, isNull);
      expect(lease.leaseStatus, LeaseStatus.draft);
    });

    test('displayRent formats cents to dollars', () {
      final lease = LeaseItem.fromJson({...sampleJson, 'monthlyRent': 95000});
      expect(lease.displayRent, '950.00 \$');
    });

    test('displayRent returns -- for null or zero', () {
      expect(
        LeaseItem.fromJson({...sampleJson}..remove('monthlyRent')).displayRent,
        '--',
      );
      expect(
        LeaseItem.fromJson({...sampleJson, 'monthlyRent': 0}).displayRent,
        '--',
      );
    });

    test('displayDeposit formats cents to dollars', () {
      final lease = LeaseItem.fromJson({...sampleJson, 'deposit': 50000});
      expect(lease.displayDeposit, '500.00 \$');
    });

    test('displayDeposit returns -- for null or zero', () {
      expect(
        LeaseItem.fromJson({...sampleJson}..remove('deposit')).displayDeposit,
        '--',
      );
    });

    test('toJson includes non-null fields', () {
      final lease = LeaseItem.fromJson(sampleJson);
      final json = lease.toJson();
      expect(json['id'], 'lease-1');
      expect(json['buildingId'], 'bldg-1');
      expect(json['monthlyRent'], 120000);
      expect(json['status'], 'active');
      expect(json['startDate'], isNotNull);
      expect(json['endDate'], isNotNull);
    });

    test('toJson omits null fields', () {
      final lease = LeaseItem.fromJson({});
      final json = lease.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('buildingId'), isFalse);
      expect(json.containsKey('monthlyRent'), isFalse);
    });
  });
}
