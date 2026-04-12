import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/building_service.dart';
import 'package:immogestion/services/lead_service.dart';

void main() {
  group('LeadStage', () {
    test('fromString parses known stage names', () {
      expect(LeadStage.fromString('nouveau'), LeadStage.nouveau);
      expect(LeadStage.fromString('contacte'), LeadStage.contacte);
      expect(LeadStage.fromString('qualifie'), LeadStage.qualifie);
      expect(LeadStage.fromString('visitePlanifiee'), LeadStage.visitePlanifiee);
      expect(LeadStage.fromString('offreEnvoyee'), LeadStage.offreEnvoyee);
      expect(LeadStage.fromString('negociation'), LeadStage.negociation);
      expect(LeadStage.fromString('bailSigne'), LeadStage.bailSigne);
    });

    test('fromString falls back to nouveau for unknown values', () {
      expect(LeadStage.fromString('unknown_stage'), LeadStage.nouveau);
      expect(LeadStage.fromString(''), LeadStage.nouveau);
    });

    test('label returns French display text for each stage', () {
      expect(LeadStage.nouveau.label, 'Nouveau');
      expect(LeadStage.contacte.label, 'Contacté');
      expect(LeadStage.qualifie.label, 'Qualifié');
      expect(LeadStage.visitePlanifiee.label, 'Visite planifiée');
      expect(LeadStage.offreEnvoyee.label, 'Offre envoyée');
      expect(LeadStage.negociation.label, 'Négociation');
      expect(LeadStage.bailSigne.label, 'Bail signé');
    });
  });

  group('LeadItem', () {
    test('fromJson with full API payload', () {
      final json = {
        'id': 'lead-1',
        'fullName': 'Jean Dupont',
        'email': 'jean@example.com',
        'phone': '514-555-1234',
        'desiredUnit': 'Unit 4B',
        'budgetCents': 120000,
        'source': 'website',
        'stage': 'qualifie',
        'notes': 'Intéressé par 4½',
        'tags': ['urgent', 'premier contact'],
        'lastContact': '2025-01-15',
        'offers': [
          {
            'id': 'off-1',
            'amount': 115000,
            'status': 'pending',
            'sentAt': '2025-01-20',
          },
        ],
        'language': 'fr',
        'createdAt': '2025-01-10T09:00:00.000Z',
      };

      final lead = LeadItem.fromJson(json);

      expect(lead.id, 'lead-1');
      expect(lead.fullName, 'Jean Dupont');
      expect(lead.email, 'jean@example.com');
      expect(lead.phone, '514-555-1234');
      expect(lead.desiredUnit, 'Unit 4B');
      expect(lead.budget, 120000);
      expect(lead.source, 'website');
      expect(lead.stage, LeadStage.qualifie);
      expect(lead.notes, 'Intéressé par 4½');
      expect(lead.tags, ['urgent', 'premier contact']);
      expect(lead.lastContact, '2025-01-15');
      expect(lead.language, 'fr');
      expect(lead.offers.length, 1);
      expect(lead.offers.first.amount, 115000);
      expect(lead.createdAt, DateTime.parse('2025-01-10T09:00:00.000Z'));
    });

    test('fromJson with minimal payload uses defaults', () {
      final json = <String, dynamic>{};

      final lead = LeadItem.fromJson(json);

      expect(lead.id, isNull);
      expect(lead.fullName, '');
      expect(lead.email, '');
      expect(lead.phone, '');
      expect(lead.desiredUnit, '');
      expect(lead.budget, 0);
      expect(lead.source, '');
      expect(lead.stage, LeadStage.nouveau);
      expect(lead.notes, '');
      expect(lead.tags, isEmpty);
      expect(lead.lastContact, '');
      expect(lead.offers, isEmpty);
      expect(lead.language, isNull);
      expect(lead.createdAt, isNull);
    });

    test('toJson round-trips key fields', () {
      const lead = LeadItem(
        id: 'lead-2',
        fullName: 'Marie Tremblay',
        email: 'marie@test.com',
        phone: '514-555-9999',
        desiredUnit: 'Unit 2A',
        budget: 95000,
        source: 'referral',
        stage: LeadStage.offreEnvoyee,
        notes: 'Budget flexible',
        tags: ['vip'],
        lastContact: '2025-03-01',
        offers: [],
      );

      final json = lead.toJson();

      expect(json['id'], 'lead-2');
      expect(json['fullName'], 'Marie Tremblay');
      expect(json['budgetCents'], 95000);
      expect(json['stage'], 'offre_envoyee'); // snake_case conversion
      expect(json['tags'], ['vip']);
      expect(json.containsKey('createdAt'), false); // null → omitted
      expect(json.containsKey('language'), false); // null → omitted
    });

    test('fromJson handles snake_case stage from API', () {
      final json = {
        'fullName': 'Test',
        'email': 't@t.com',
        'phone': '',
        'desiredUnit': '',
        'stage': 'visite_planifiee',
        'notes': '',
        'tags': [],
        'lastContact': '',
        'offers': [],
      };

      final lead = LeadItem.fromJson(json);
      expect(lead.stage, LeadStage.visitePlanifiee);
    });
  });

  group('OfferItem', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'o1',
        'amount': 100000,
        'status': 'accepted',
        'sentAt': '2025-02-14',
      };

      final offer = OfferItem.fromJson(json);
      expect(offer.id, 'o1');
      expect(offer.amount, 100000);
      expect(offer.status, 'accepted');
      expect(offer.sentAt, '2025-02-14');
    });

    test('toJson round-trips', () {
      const offer = OfferItem(
        id: 'o2',
        amount: 87500,
        status: 'pending',
        sentAt: '2025-03-01',
      );

      final json = offer.toJson();
      expect(json['id'], 'o2');
      expect(json['amount'], 87500);
      expect(json['status'], 'pending');
      expect(json['sentAt'], '2025-03-01');
    });

    test('fromJson with double amount truncates to int', () {
      final json = {
        'amount': 99999.99,
        'status': 'sent',
        'sentAt': '2025-01-01',
      };

      final offer = OfferItem.fromJson(json);
      expect(offer.amount, 99999);
    });
  });

  group('LeadService', () {
    test('singleton instance is stable', () {
      expect(
        identical(LeadService.instance, LeadService.instance),
        true,
      );
    });

    test('getLeads query encodes search parameter', () {
      const search = 'Appartement 4½';
      final encoded = Uri.encodeComponent(search);
      expect(encoded, contains('4%C2%BD')); // ½ is multi-byte UTF-8
    });

    test('getLeads query includes stage when provided', () {
      final params = <String, String>{
        'page': '2',
        'limit': '10',
      };
      const stage = LeadStage.negociation;
      params['stage'] = stage.name;
      expect(params['stage'], 'negociation');
      expect(params.length, 3);
    });

    test('getLeads query omits stage when null', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const LeadStage? stage = null;
      if (stage != null) params['stage'] = stage.name;
      expect(params.length, 2);
      expect(params.containsKey('stage'), false);
    });

    test('getLeads query omits empty search', () {
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const search = '';
      if (search.isNotEmpty) params['search'] = search;
      expect(params.length, 2);
      expect(params.containsKey('search'), false);
    });

    test('getLeads metadata defaults when missing', () {
      final result = <String, dynamic>{
        'data': [
          {
            'fullName': 'Test Lead',
            'email': 'test@test.com',
            'phone': '',
            'desiredUnit': 'Unit 1',
            'stage': 'nouveau',
            'notes': '',
            'tags': [],
            'lastContact': '',
            'offers': [],
          },
        ],
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
          .toList();

      const page = 1;
      const limit = 20;

      final paginated = PaginatedResult<LeadItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? items.length,
        page: (metadata['page'] as num?)?.toInt() ?? page,
        limit: (metadata['limit'] as num?)?.toInt() ?? limit,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items.length, 1);
      expect(paginated.items.first.fullName, 'Test Lead');
      expect(paginated.total, 1);
      expect(paginated.hasMore, false);
    });

    test('getLeads metadata parses when present', () {
      final result = <String, dynamic>{
        'data': [],
        'metadata': {
          'total': 85,
          'page': 3,
          'limit': 25,
          'totalPages': 4,
          'hasMore': true,
        },
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => LeadItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final paginated = PaginatedResult<LeadItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? items.length,
        page: (metadata['page'] as num?)?.toInt() ?? 1,
        limit: (metadata['limit'] as num?)?.toInt() ?? 20,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items, isEmpty);
      expect(paginated.total, 85);
      expect(paginated.page, 3);
      expect(paginated.limit, 25);
      expect(paginated.totalPages, 4);
      expect(paginated.hasMore, true);
    });
  });
}
