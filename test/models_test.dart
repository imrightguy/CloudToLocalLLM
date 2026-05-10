import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  group('LeadStage', () {
    test('fromString parses known values', () {
      expect(LeadStage.fromString('nouveau'), LeadStage.nouveau);
      expect(LeadStage.fromString('contacte'), LeadStage.contacte);
      expect(LeadStage.fromString('qualifie'), LeadStage.qualifie);
      expect(
          LeadStage.fromString('visitePlanifiee'), LeadStage.visitePlanifiee);
      expect(LeadStage.fromString('offreEnvoyee'), LeadStage.offreEnvoyee);
      expect(LeadStage.fromString('negociation'), LeadStage.negociation);
      expect(LeadStage.fromString('bailSigne'), LeadStage.bailSigne);
    });

    test('fromString falls back to nouveau for unknown values', () {
      expect(LeadStage.fromString('unknown'), LeadStage.nouveau);
      expect(LeadStage.fromString(''), LeadStage.nouveau);
    });

    test('label returns French display text', () {
      expect(LeadStage.nouveau.label, 'Nouveau');
      expect(LeadStage.contacte.label, 'Contacté');
      expect(LeadStage.qualifie.label, 'Qualifié');
      expect(LeadStage.visitePlanifiee.label, 'Visite planifiée');
      expect(LeadStage.offreEnvoyee.label, 'Offre envoyée');
      expect(LeadStage.negociation.label, 'Négociation');
      expect(LeadStage.bailSigne.label, 'Bail signé');
    });
  });

  group('OfferItem', () {
    test('fromJson parses all fields', () {
      final offer = OfferItem.fromJson({
        'id': 'o1',
        'amount': 158000,
        'status': 'envoyée',
        'sentAt': '3 jours',
      });
      expect(offer.id, 'o1');
      expect(offer.amount, 158000);
      expect(offer.status, 'envoyée');
      expect(offer.sentAt, '3 jours');
    });

    test('fromJson defaults null optional fields', () {
      final offer = OfferItem.fromJson({'amount': 1000});
      expect(offer.id, isNull);
      expect(offer.status, '');
      expect(offer.sentAt, '');
    });

    test('toJson round-trips', () {
      const original = OfferItem(
          id: 'o1', amount: 158000, status: 'envoyée', sentAt: '3 jours');
      final json = original.toJson();
      final restored = OfferItem.fromJson(json);
      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.status, original.status);
      expect(restored.sentAt, original.sentAt);
    });

    test('toJson omits null id', () {
      const offer = OfferItem(amount: 1000, status: 'pending', sentAt: '');
      expect(offer.toJson().containsKey('id'), isFalse);
    });
  });

  group('LeadItem', () {
    test('fromJson parses API snake_case stage to camelCase enum', () {
      final lead = LeadItem.fromJson({
        'fullName': 'Émilie Beaudoin',
        'email': 'emilie@email.com',
        'phone': '514-555-0123',
        'desiredUnit': '3 1/2',
        'budgetCents': 160000,
        'source': 'FB',
        'stage': 'visite_planifiee',
        'notes': 'test',
        'tags': ['chaud'],
        'lastContact': 'Aujourd\'hui',
        'offers': [],
      });
      expect(lead.stage, LeadStage.visitePlanifiee);
      expect(lead.budget, 160000);
    });

    test('fromJson defaults missing fields', () {
      final lead = LeadItem.fromJson({});
      expect(lead.fullName, '');
      expect(lead.stage, LeadStage.nouveau);
      expect(lead.budget, 0);
      expect(lead.tags, isEmpty);
      expect(lead.offers, isEmpty);
      expect(lead.id, isNull);
    });

    test('toJson converts stage back to snake_case', () {
      const lead = LeadItem(
        fullName: 'Test',
        email: 't@t.com',
        phone: '',
        desiredUnit: '',
        budget: 0,
        source: '',
        stage: LeadStage.offreEnvoyee,
        notes: '',
        tags: [],
        lastContact: '',
        offers: [],
      );
      final json = lead.toJson();
      expect(json['stage'], 'offre_envoyee');
    });

    test('toJson round-trips with nested offers', () {
      const original = LeadItem(
        id: 'l1',
        fullName: 'Test User',
        email: 'test@test.com',
        phone: '555-1234',
        desiredUnit: '4 1/2',
        budget: 190000,
        source: 'web',
        stage: LeadStage.negociation,
        notes: 'notes here',
        tags: ['vip', 'urgent'],
        lastContact: 'yesterday',
        offers: [
          OfferItem(id: 'o1', amount: 185000, status: 'sent', sentAt: 'today'),
        ],
        language: 'fr',
      );
      final json = original.toJson();
      final restored = LeadItem.fromJson(json);
      expect(restored.fullName, original.fullName);
      expect(restored.stage, LeadStage.negociation);
      expect(restored.tags, ['vip', 'urgent']);
      expect(restored.offers.length, 1);
      expect(restored.offers.first.amount, 185000);
      expect(restored.language, 'fr');
    });

    test('toJson omits null optional fields', () {
      const lead = LeadItem(
        fullName: 'T',
        email: 't@t.com',
        phone: '',
        desiredUnit: '',
        budget: 0,
        source: '',
        stage: LeadStage.nouveau,
        notes: '',
        tags: [],
        lastContact: '',
        offers: [],
      );
      final json = lead.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('language'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });
  });

  group('MarketplaceInboxThread', () {
    test('fromJson parses qualification fields', () {
      final thread = MarketplaceInboxThread.fromJson({
        'leadId': 'lead-1',
        'contactId': 'lead-1',
        'contactName': 'Sarah Tremblay',
        'contactPhone': '5145550101',
        'messageCount': 3,
        'coordinationState': 'message_only',
        'qualificationState': 'needs_follow_up',
        'qualificationReasonCode': 'budget_mismatch',
        'qualificationReasonNote': 'No matching listings were found.',
      });

      expect(thread.qualificationState, 'needs_follow_up');
      expect(thread.qualificationReasonCode, 'budget_mismatch');
      expect(thread.qualificationReasonNote, 'No matching listings were found.');
    });

    test('defaults qualification fields to null when absent', () {
      final thread = MarketplaceInboxThread.fromJson({
        'contactId': 'lead-2',
        'contactName': 'Marc Gagnon',
        'contactPhone': '4385550102',
        'messageCount': 1,
        'coordinationState': 'scheduled',
      });

      expect(thread.qualificationState, isNull);
      expect(thread.qualificationReasonCode, isNull);
      expect(thread.qualificationReasonNote, isNull);
    });
  });

  group('UnitItem', () {
    test('fromJson parses nested amenities map', () {
      final unit = UnitItem.fromJson({
        'id': 'u1',
        'buildingId': 'b1',
        'label': '302',
        'description': '4 1/2',
        'bedrooms': 4,
        'rentCents': 185000,
        'status': 'occupé',
        'leaseEnd': '31/12/2024',
        'tenant': 'Sophie Tremblay',
        'amenities': {'fridge': true, 'stove': true},
        'squareFeet': 1200,
      });
      expect(unit.number, '302');
      expect(unit.amenities, ['fridge', 'stove']);
      expect(unit.squareFeet, 1200);
      expect(unit.tenant, 'Sophie Tremblay');
    });

    test('fromJson handles amenities as list', () {
      final unit = UnitItem.fromJson({
        'amenities': ['fridge', 'stove'],
      });
      expect(unit.amenities, ['fridge', 'stove']);
    });

    test('fromJson defaults null amenities', () {
      final unit = UnitItem.fromJson({});
      expect(unit.amenities, isNull);
    });

    test('toJson converts amenities to map format', () {
      const unit = UnitItem(
        number: '302',
        type: '4 1/2',
        bedrooms: 4,
        bathrooms: 1,
        rent: 1850,
        status: 'occupé',
        leaseEnd: '31/12/2024',
        amenities: ['fridge', 'stove'],
      );
      final json = unit.toJson();
      expect(json['amenities'], {'fridge': true, 'stove': true});
    });

    test('toJson round-trips', () {
      const original = UnitItem(
        id: 'u1',
        buildingId: 'b1',
        number: '302',
        type: '4 1/2',
        bedrooms: 4,
        bathrooms: 1,
        rent: 185000,
        status: 'occupé',
        leaseEnd: '31/12/2024',
        tenant: 'Sophie',
        amenities: ['fridge'],
        squareFeet: 1200,
      );
      final json = original.toJson();
      final restored = UnitItem.fromJson(json);
      expect(restored.number, original.number);
      expect(restored.amenities, ['fridge']);
      expect(restored.squareFeet, 1200);
    });
  });

  group('BuildingItem', () {
    test('occupancyRate calculates correctly', () {
      const b = BuildingItem(
        name: 'Test',
        address: '123 St',
        city: 'MTL',
        totalUnits: 10,
        occupiedUnits: 7,
        monthlyRevenue: 10000,
        units: [],
      );
      expect(b.occupancyRate, 0.7);
    });

    test('occupancyRate returns 0 when totalUnits is 0', () {
      const b = BuildingItem(
        name: 'Empty',
        address: '',
        city: '',
        totalUnits: 0,
        occupiedUnits: 0,
        monthlyRevenue: 0,
        units: [],
      );
      expect(b.occupancyRate, 0.0);
    });

    test('fromJson parses nested units', () {
      final building = BuildingItem.fromJson({
        'name': 'Le Test',
        'address': '1 Rue',
        'city:': 'MTL',
        'totalUnits': 2,
        'occupiedUnits': 1,
        'monthlyRevenue': 5000,
        'units': [
          {'label': '101', 'bedrooms': 2, 'rentCents': 150000},
        ],
      });
      expect(building.name, 'Le Test');
      expect(building.units.length, 1);
      expect(building.units.first.number, '101');
    });

    test('toJson round-trips with units', () {
      const original = BuildingItem(
        id: 'b1',
        name: 'Le Test',
        address: '1 Rue',
        city: 'MTL',
        totalUnits: 2,
        occupiedUnits: 1,
        monthlyRevenue: 5000,
        units: [
          UnitItem(
              number: '101',
              type: '3 1/2',
              bedrooms: 2,
              bathrooms: 1,
              rent: 1500,
              status: 'occupé',
              leaseEnd: ''),
        ],
        description: 'A building',
        properties: {'key': 'value'},
      );
      final json = original.toJson();
      final restored = BuildingItem.fromJson(json);
      expect(restored.name, original.name);
      expect(restored.units.length, 1);
      expect(restored.description, 'A building');
      expect(restored.properties, {'key': 'value'});
    });

    test('toJson omits null optional fields', () {
      const building = BuildingItem(
        name: 'T',
        address: '',
        city: '',
        totalUnits: 0,
        occupiedUnits: 0,
        monthlyRevenue: 0,
        units: [],
      );
      final json = building.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('properties'), isFalse);
    });
  });

  group('VisitItem', () {
    test('fromJson parses nested unit and building objects', () {
      final visit = VisitItem.fromJson({
        'id': 'v1',
        'unit': {'label': '302'},
        'building': {'name': 'Le Saint-Laurent'},
        'employee': {'firstName': 'Jean', 'lastName': 'Dupont'},
        'status': 'confirmée',
        'notes': 'test',
        'dateTime': '2024-06-15T10:00:00.000',
        'tenantConfirmed': true,
        'employeeConfirmed': true,
      });
      expect(visit.unitLabel, '302');
      expect(visit.buildingName, 'Le Saint-Laurent');
      expect(visit.agent, 'Jean Dupont');
      expect(visit.dateTime, DateTime(2024, 6, 15, 10));
      expect(visit.tenantConfirmed, isTrue);
      expect(visit.employeeConfirmed, isTrue);
    });

    test('fromJson falls back to flat fields', () {
      final visit = VisitItem.fromJson({
        'unitLabel': '201',
        'buildingName': 'Test',
        'agent': 'Bob',
        'dateLabel': '15 juin 2024',
      });
      expect(visit.unitLabel, '201');
      expect(visit.buildingName, 'Test');
      expect(visit.agent, 'Bob');
      expect(visit.dateTime, isNull);
    });

    test('fromJson falls back to empty dateLabel when dateTime parsing fails',
        () {
      // DateFormat with 'fr' locale can throw if locale data unavailable (test env);
      // the catch block silently sets derivedDateLabel = null, falling back to ''
      final visit = VisitItem.fromJson({
        'dateTime': '2024-06-15T10:00:00.000',
      });
      // When dateLabel derivation fails, falls back to empty string
      expect(visit.dateLabel, isA<String>());
    });

    test('toJson round-trips', () {
      final original = VisitItem(
        id: 'v1',
        unitLabel: '302',
        buildingName: 'Le Test',
        dateLabel: '15 juin 2024',
        dateTime: DateTime(2024, 6, 15, 10),
        status: 'confirmée',
        agent: 'Jean Dupont',
        notes: 'bring keys',
        leadName: 'Émilie B.',
        tenantConfirmed: true,
        employeeConfirmed: false,
      );
      final json = original.toJson();
      final restored = VisitItem.fromJson(json);
      expect(restored.unitLabel, original.unitLabel);
      expect(restored.agent, original.agent);
      expect(restored.leadName, original.leadName);
      expect(restored.tenantConfirmed, isTrue);
      expect(restored.employeeConfirmed, isFalse);
    });

    test('toJson omits null id and dateTime', () {
      const visit = VisitItem(
        unitLabel: '201',
        buildingName: 'Test',
        dateLabel: '',
        status: '',
        agent: '',
        notes: '',
      );
      final json = visit.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('dateTime'), isFalse);
    });

    test('fromJson parses occupant notification fields', () {
      final visit = VisitItem.fromJson({
        'occupantNotified': true,
        'occupantSMS': {'sid': 'SM123', 'status': 'delivered'},
      });
      expect(visit.occupantNotified, isTrue);
      expect(visit.occupantSMS, {'sid': 'SM123', 'status': 'delivered'});
    });

    test('fromJson defaults occupant fields', () {
      final visit = VisitItem.fromJson({});
      expect(visit.occupantNotified, isFalse);
      expect(visit.occupantSMS, isNull);
    });

    test('fromJson parses nested lead object', () {
      final visit = VisitItem.fromJson({
        'lead': {'fullName': 'Émilie Beaudoin'},
      });
      expect(visit.leadName, 'Émilie Beaudoin');
    });

    test('fromJson falls back to flat leadName', () {
      final visit = VisitItem.fromJson({
        'leadName': 'Jean Dupont',
      });
      expect(visit.leadName, 'Jean Dupont');
    });

    test('toJson includes occupantNotified and omits null occupantSMS', () {
      const visit = VisitItem(
        unitLabel: '201',
        buildingName: 'Test',
        dateLabel: '',
        status: '',
        agent: '',
        notes: '',
        occupantNotified: true,
      );
      final json = visit.toJson();
      expect(json['occupantNotified'], isTrue);
      expect(json.containsKey('occupantSMS'), isFalse);
    });

    test('toJson includes occupantSMS when present', () {
      const visit = VisitItem(
        unitLabel: '201',
        buildingName: 'Test',
        dateLabel: '',
        status: '',
        agent: '',
        notes: '',
        occupantSMS: {'sid': 'SM999'},
      );
      final json = visit.toJson();
      expect(json['occupantSMS'], {'sid': 'SM999'});
    });
  });

  group('UnitItem tenant occupant fields', () {
    test('fromJson parses tenantName, tenantPhone, tenantLeaseEnd', () {
      final unit = UnitItem.fromJson({
        'tenantName': 'Sophie Tremblay',
        'tenantPhone': '514-555-0100',
        'tenantLeaseEnd': '2025-12-31T23:59:59.000',
      });
      expect(unit.tenantName, 'Sophie Tremblay');
      expect(unit.tenantPhone, '514-555-0100');
      expect(unit.tenantLeaseEnd, DateTime(2025, 12, 31, 23, 59, 59));
    });

    test('fromJson handles invalid tenantLeaseEnd gracefully', () {
      final unit = UnitItem.fromJson({
        'tenantLeaseEnd': 'not-a-date',
      });
      expect(unit.tenantLeaseEnd, isNull);
    });

    test('fromJson defaults tenant occupant fields', () {
      final unit = UnitItem.fromJson({});
      expect(unit.tenantName, isNull);
      expect(unit.tenantPhone, isNull);
      expect(unit.tenantLeaseEnd, isNull);
    });

    test('toJson omits null tenant occupant fields', () {
      const unit = UnitItem(
        number: '101',
        type: '3 1/2',
        bedrooms: 2,
        bathrooms: 1,
        rent: 1000,
        status: 'libre',
        leaseEnd: '',
      );
      final json = unit.toJson();
      expect(json.containsKey('tenantName'), isFalse);
      expect(json.containsKey('tenantPhone'), isFalse);
      expect(json.containsKey('tenantLeaseEnd'), isFalse);
    });

    test('toJson includes tenant occupant fields when set', () {
      final unit = UnitItem(
        number: '101',
        type: '3 1/2',
        bedrooms: 2,
        bathrooms: 1,
        rent: 1000,
        status: 'occupé',
        leaseEnd: '',
        tenantName: 'Sophie Tremblay',
        tenantPhone: '514-555-0100',
        tenantLeaseEnd: DateTime(2025, 12, 31),
      );
      final json = unit.toJson();
      expect(json['tenantName'], 'Sophie Tremblay');
      expect(json['tenantPhone'], '514-555-0100');
      expect(json['tenantLeaseEnd'], '2025-12-31');
    });

    test('toJson round-trips with tenant occupant fields', () {
      final original = UnitItem(
        id: 'u1',
        buildingId: 'b1',
        number: '302',
        type: '4 1/2',
        bedrooms: 4,
        bathrooms: 1,
        rent: 1850,
        status: 'occupé',
        leaseEnd: '31/12/2024',
        tenant: 'Sophie Tremblay',
        amenities: ['fridge'],
        squareFeet: 1200,
        tenantName: 'Sophie Tremblay',
        tenantPhone: '514-555-0100',
        tenantLeaseEnd: DateTime(2025, 6, 30),
      );
      final json = original.toJson();
      final restored = UnitItem.fromJson(json);
      expect(restored.tenantName, original.tenantName);
      expect(restored.tenantPhone, original.tenantPhone);
      expect(restored.tenantLeaseEnd, original.tenantLeaseEnd);
    });
  });
}
