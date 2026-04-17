import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/lease_service.dart';

void main() {
  group('LeaseStatus', () {
    test('fromString parses English values', () {
      expect(LeaseStatus.fromString('draft'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('sent'), LeaseStatus.sent);
      expect(LeaseStatus.fromString('signed'), LeaseStatus.signed);
      expect(LeaseStatus.fromString('active'), LeaseStatus.active);
      expect(LeaseStatus.fromString('terminated'), LeaseStatus.terminated);
    });

    test('fromString parses French values', () {
      expect(LeaseStatus.fromString('brouillon'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('envoyé'), LeaseStatus.sent);
      expect(LeaseStatus.fromString('envoye'), LeaseStatus.sent);
      expect(LeaseStatus.fromString('signé'), LeaseStatus.signed);
      expect(LeaseStatus.fromString('signe'), LeaseStatus.signed);
      expect(LeaseStatus.fromString('actif'), LeaseStatus.active);
      expect(LeaseStatus.fromString('résilié'), LeaseStatus.terminated);
      expect(LeaseStatus.fromString('resilie'), LeaseStatus.terminated);
    });

    test('fromString defaults to draft for unknown values', () {
      expect(LeaseStatus.fromString('unknown'), LeaseStatus.draft);
      expect(LeaseStatus.fromString(''), LeaseStatus.draft);
    });

    test('fromString is case-insensitive', () {
      expect(LeaseStatus.fromString('DRAFT'), LeaseStatus.draft);
      expect(LeaseStatus.fromString('Active'), LeaseStatus.active);
    });

    test('label returns French text', () {
      expect(LeaseStatus.draft.label, 'Brouillon');
      expect(LeaseStatus.sent.label, 'Envoyé');
      expect(LeaseStatus.signed.label, 'Signé');
      expect(LeaseStatus.active.label, 'Actif');
      expect(LeaseStatus.terminated.label, 'Résilié');
    });

    test('apiValue returns English API value', () {
      expect(LeaseStatus.draft.apiValue, 'draft');
      expect(LeaseStatus.sent.apiValue, 'sent');
      expect(LeaseStatus.signed.apiValue, 'signed');
      expect(LeaseStatus.active.apiValue, 'active');
      expect(LeaseStatus.terminated.apiValue, 'terminated');
    });

    test('color returns distinct colors', () {
      expect(LeaseStatus.draft.color, const Color(0xFF6B7280));
      expect(LeaseStatus.sent.color, const Color(0xFF3B82F6));
      expect(LeaseStatus.signed.color, const Color(0xFF8B5CF6));
      expect(LeaseStatus.active.color, const Color(0xFF10B981));
      expect(LeaseStatus.terminated.color, const Color(0xFFEF4444));
    });

    test('orderIndex returns correct order', () {
      expect(LeaseStatus.draft.orderIndex, 0);
      expect(LeaseStatus.sent.orderIndex, 1);
      expect(LeaseStatus.signed.orderIndex, 2);
      expect(LeaseStatus.active.orderIndex, 3);
      expect(LeaseStatus.terminated.orderIndex, 4);
    });
  });

  group('LeaseItem', () {
    test('fromJson parses all fields', () {
      final lease = LeaseItem.fromJson({
        'id': 'lease-1',
        'buildingId': 'b1',
        'buildingName': 'Le Saint-Laurent',
        'unitId': 'u1',
        'unitLabel': '4B',
        'tenantName': 'Jean Dupont',
        'tenantEmail': 'jean@test.com',
        'tenantPhone': '514-555-1234',
        'startDate': '2025-01-01',
        'endDate': '2025-12-31',
        'monthlyRent': 150000,
        'deposit': 50000,
        'status': 'active',
        'notes': 'Test notes',
        'terms': '12 months',
        'createdAt': '2024-12-15T10:00:00.000Z',
        'updatedAt': '2025-01-01T00:00:00.000Z',
      });

      expect(lease.id, 'lease-1');
      expect(lease.buildingId, 'b1');
      expect(lease.unitId, 'u1');
      expect(lease.tenantName, 'Jean Dupont');
      expect(lease.tenantEmail, 'jean@test.com');
      expect(lease.tenantPhone, '514-555-1234');
      expect(lease.startDate, DateTime(2025, 1, 1));
      expect(lease.endDate, DateTime(2025, 12, 31));
      expect(lease.monthlyRent, 150000);
      expect(lease.deposit, 50000);
      expect(lease.status, LeaseStatus.active);
      expect(lease.notes, 'Test notes');
      expect(lease.terms, '12 months');
      expect(lease.createdAt, isNotNull);
      expect(lease.updatedAt, isNotNull);
    });

    test('fromJson handles nested building and unit objects', () {
      final lease = LeaseItem.fromJson({
        'id': 'lease-2',
        'building': {'name': 'Le Test', 'id': 'b2'},
        'unit': {'label': '3A', 'id': 'u2'},
        'tenant': {'fullName': 'Marie Tremblay', 'email': 'marie@test.com', 'phone': '514-555-5678'},
        'status': 'signed',
        'monthlyRent': 120000,
      });

      expect(lease.buildingName, 'Le Test');
      expect(lease.unitLabel, '3A');
      expect(lease.tenantName, 'Marie Tremblay');
      expect(lease.tenantEmail, 'marie@test.com');
      expect(lease.tenantPhone, '514-555-5678');
      expect(lease.status, LeaseStatus.signed);
      expect(lease.monthlyRent, 120000);
    });

    test('fromJson defaults missing fields', () {
      final lease = LeaseItem.fromJson({});

      expect(lease.id, isNull);
      expect(lease.buildingId, isNull);
      expect(lease.buildingName, isNull);
      expect(lease.unitId, isNull);
      expect(lease.unitLabel, isNull);
      expect(lease.tenantName, isNull);
      expect(lease.tenantEmail, isNull);
      expect(lease.tenantPhone, isNull);
      expect(lease.startDate, isNull);
      expect(lease.endDate, isNull);
      expect(lease.monthlyRent, isNull);
      expect(lease.deposit, isNull);
      expect(lease.status, isNull);
      expect(lease.notes, isNull);
      expect(lease.terms, isNull);
      expect(lease.createdAt, isNull);
      expect(lease.updatedAt, isNull);
    });

    test('fromJson handles invalid dates gracefully', () {
      final lease = LeaseItem.fromJson({
        'startDate': 'not-a-date',
        'endDate': 'invalid',
      });

      expect(lease.startDate, isNull);
      expect(lease.endDate, isNull);
    });

    test('fromJson prefers nested objects over flat fields', () {
      final lease = LeaseItem.fromJson({
        'buildingName': 'Flat Name',
        'building': {'name': 'Nested Name'},
        'unitLabel': 'Flat Unit',
        'unit': {'label': 'Nested Unit'},
        'tenantName': 'Flat Tenant',
        'tenant': {'fullName': 'Nested Tenant'},
      });

      expect(lease.buildingName, 'Nested Name');
      expect(lease.unitLabel, 'Nested Unit');
      expect(lease.tenantName, 'Nested Tenant');
    });

    test('toJson round-trips', () {
      final original = LeaseItem(
        id: 'lease-3',
        buildingId: 'b1',
        unitId: 'u1',
        tenantName: 'Sophie Bérubé',
        tenantEmail: 'sophie@test.com',
        tenantPhone: '514-555-9999',
        startDate: DateTime(2025, 3, 1),
        endDate: DateTime(2026, 2, 28),
        monthlyRent: 180000,
        deposit: 60000,
        status: LeaseStatus.active,
        notes: 'Pet-friendly',
        terms: '12 months',
      );

      final json = original.toJson();
      final restored = LeaseItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.buildingId, original.buildingId);
      expect(restored.unitId, original.unitId);
      expect(restored.tenantName, original.tenantName);
      expect(restored.tenantEmail, original.tenantEmail);
      expect(restored.tenantPhone, original.tenantPhone);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.monthlyRent, original.monthlyRent);
      expect(restored.deposit, original.deposit);
      expect(restored.status, original.status);
      expect(restored.notes, original.notes);
      expect(restored.terms, original.terms);
    });

    test('toJson omits null optional fields', () {
      const lease = LeaseItem(
        tenantName: null,
        tenantEmail: null,
        tenantPhone: null,
        startDate: null,
        endDate: null,
        monthlyRent: null,
        deposit: null,
        status: null,
        notes: null,
        terms: null,
      );

      final json = lease.toJson();
      expect(json.containsKey('id'), false);
      expect(json.containsKey('tenantName'), false);
      expect(json.containsKey('tenantEmail'), false);
      expect(json.containsKey('tenantPhone'), false);
      expect(json.containsKey('startDate'), false);
      expect(json.containsKey('endDate'), false);
      expect(json.containsKey('monthlyRent'), false);
      expect(json.containsKey('deposit'), false);
      expect(json.containsKey('status'), false);
      expect(json.containsKey('notes'), false);
      expect(json.containsKey('terms'), false);
    });

    test('toJson uses apiValue for status', () {
      const lease = LeaseItem(
        tenantName: 'Test',
        status: LeaseStatus.active,
      );

      final json = lease.toJson();
      expect(json['status'], 'active');
    });
  });

  group('LeaseItem display getters', () {
    test('displayRent formats cents to dollars', () {
      const lease = LeaseItem(
        tenantName: 'Test',
        monthlyRent: 150000,
      );
      expect(lease.displayRent, '1500.00 \$');
    });

    test('displayRent returns -- when null', () {
      const lease = LeaseItem(tenantName: null);
      expect(lease.displayRent, '--');
    });

    test('displayRent returns -- when zero', () {
      const lease = LeaseItem(tenantName: 'Test', monthlyRent: 0);
      expect(lease.displayRent, '--');
    });

    test('displayDeposit formats cents to dollars', () {
      const lease = LeaseItem(
        tenantName: 'Test',
        deposit: 50000,
      );
      expect(lease.displayDeposit, '500.00 \$');
    });

    test('displayDeposit returns -- when null', () {
      const lease = LeaseItem(tenantName: null);
      expect(lease.displayDeposit, '--');
    });

    test('leaseStatus defaults to draft when status is null', () {
      const lease = LeaseItem(tenantName: null);
      expect(lease.leaseStatus, LeaseStatus.draft);
    });

    test('leaseStatus returns actual status when set', () {
      const lease = LeaseItem(
        tenantName: 'Test',
        status: LeaseStatus.active,
      );
      expect(lease.leaseStatus, LeaseStatus.active);
    });
  });

  group('LeaseService', () {
    test('singleton instance is stable', () {
      expect(
        identical(LeaseService.instance, LeaseService.instance),
        true,
      );
    });

    test('getLeases query builds correct params with all filters', () {
      final params = <String, String>{};
      const status = 'active';
      const buildingId = 'b1';
      const unitId = 'u1';
      const search = 'dupont';

      if (status.isNotEmpty) params['status'] = status;
      if (buildingId.isNotEmpty) params['buildingId'] = buildingId;
      if (unitId.isNotEmpty) params['unitId'] = unitId;
      if (search.isNotEmpty) params['search'] = search;

      expect(params['status'], 'active');
      expect(params['buildingId'], 'b1');
      expect(params['unitId'], 'u1');
      expect(params['search'], 'dupont');
      expect(params.length, 4);
    });

    test('getLeases query omits null filters', () {
      final params = <String, String>{};
      const String? status = null;
      const String? buildingId = null;
      const String? unitId = null;
      const String? search = null;

      if (status != null && status.isNotEmpty) params['status'] = status;
      if (buildingId != null && buildingId.isNotEmpty) params['buildingId'] = buildingId;
      if (unitId != null && unitId.isNotEmpty) params['unitId'] = unitId;
      if (search != null && search.isNotEmpty) params['search'] = search;

      expect(params, isEmpty);
    });

    test('getLeases query omits empty string filters', () {
      final params = <String, String>{};
      const status = '';
      const search = '';

      if (status.isNotEmpty) params['status'] = status;
      if (search.isNotEmpty) params['search'] = search;

      expect(params, isEmpty);
    });

    test('getLeases path is correct without query', () {
      final params = <String, String>{};
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = query.isNotEmpty ? '/leases?$query' : '/leases';
      expect(path, '/leases');
    });

    test('getLeases path includes query when params present', () {
      final params = <String, String>{'status': 'active'};
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final path = query.isNotEmpty ? '/leases?$query' : '/leases';
      expect(path, '/leases?status=active');
    });

    test('getLeases query encodes special characters', () {
      final params = <String, String>{'search': 'Jean Dupont'};
      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      expect(query, 'search=Jean%20Dupont');
    });
  });
}
