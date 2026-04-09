import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';

void main() {
  // ---------------------------------------------------------------------------
  // LeadStage
  // ---------------------------------------------------------------------------
  group('LeadStage', () {
    test('fromString returns correct stage', () {
      expect(LeadStage.fromString('nouveau'), LeadStage.nouveau);
      expect(LeadStage.fromString('contacte'), LeadStage.contacte);
      expect(LeadStage.fromString('qualifie'), LeadStage.qualifie);
      expect(LeadStage.fromString('visitePlanifiee'), LeadStage.visitePlanifiee);
      expect(LeadStage.fromString('offreEnvoyee'), LeadStage.offreEnvoyee);
      expect(LeadStage.fromString('negociation'), LeadStage.negociation);
      expect(LeadStage.fromString('bailSigne'), LeadStage.bailSigne);
    });

    test('fromString returns nouveau for unknown value', () {
      expect(LeadStage.fromString('invalid'), LeadStage.nouveau);
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

  // ---------------------------------------------------------------------------
  // OfferItem
  // ---------------------------------------------------------------------------
  group('OfferItem', () {
    test('fromJson parses all fields', () {
      final offer = OfferItem.fromJson({
        'id': 'o1',
        'amount': 1500,
        'status': 'active',
        'sentAt': '2024-01-15',
      });

      expect(offer.id, 'o1');
      expect(offer.amount, 1500);
      expect(offer.status, 'active');
      expect(offer.sentAt, '2024-01-15');
    });

    test('fromJson uses defaults for missing optional fields', () {
      final offer = OfferItem.fromJson({'amount': 0});
      expect(offer.id, isNull);
      expect(offer.amount, 0);
      expect(offer.status, isEmpty);
      expect(offer.sentAt, isEmpty);
    });

    test('fromJson throws when amount is missing', () {
      expect(() => OfferItem.fromJson({}), throwsA(isA<TypeError>()));
    });

    test('fromJson handles amount as double', () {
      final offer = OfferItem.fromJson({'amount': 1500.5});
      expect(offer.amount, 1500);
    });

    test('toJson round-trips', () {
      const original = OfferItem(
        id: 'o1',
        amount: 1500,
        status: 'active',
        sentAt: '2024-01-15',
      );

      final json = original.toJson();
      final restored = OfferItem.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.amount, original.amount);
      expect(restored.status, original.status);
      expect(restored.sentAt, original.sentAt);
    });

    test('toJson omits null id', () {
      const offer = OfferItem(amount: 1500, status: 'active', sentAt: '');
      expect(offer.toJson().containsKey('id'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // VisitItem
  // ---------------------------------------------------------------------------
  group('VisitItem', () {
    test('fromJson parses all fields', () {
      final visit = VisitItem.fromJson({
        'id': 'v1',
        'unitLabel': 'A-101',
        'buildingName': 'Tour Eiffel',
        'dateLabel': '15 Jan 2024',
        'dateTime': '2024-01-15T10:00:00Z',
        'status': 'confirmed',
        'agent': 'Jean Dupont',
        'notes': 'RAS',
        'leadName': 'Marie Curie',
        'tenantConfirmed': true,
        'employeeConfirmed': false,
      });

      expect(visit.id, 'v1');
      expect(visit.unitLabel, 'A-101');
      expect(visit.buildingName, 'Tour Eiffel');
      expect(visit.dateTime, DateTime.utc(2024, 1, 15, 10));
      expect(visit.leadName, 'Marie Curie');
      expect(visit.tenantConfirmed, isTrue);
      expect(visit.employeeConfirmed, isFalse);
    });

    test('fromJson uses defaults', () {
      final visit = VisitItem.fromJson({
        'unitLabel': 'A-101',
        'buildingName': 'X',
        'dateLabel': 'X',
        'status': 'X',
        'agent': 'X',
        'notes': 'X',
      });

      expect(visit.id, isNull);
      expect(visit.dateTime, isNull);
      expect(visit.leadName, isNull);
      expect(visit.tenantConfirmed, isFalse);
      expect(visit.employeeConfirmed, isFalse);
    });

    test('toJson round-trips with dateTime', () {
      final original = VisitItem(
        id: 'v1',
        unitLabel: 'A-101',
        buildingName: 'Tour',
        dateLabel: '15 Jan',
        dateTime: DateTime.utc(2024, 1, 15, 10),
        status: 'confirmed',
        agent: 'Jean',
        notes: 'RAS',
        leadName: 'Marie',
        tenantConfirmed: true,
        employeeConfirmed: true,
      );

      final restored = VisitItem.fromJson(original.toJson());
      expect(restored.id, 'v1');
      expect(restored.dateTime, DateTime.utc(2024, 1, 15, 10));
      expect(restored.tenantConfirmed, isTrue);
    });

    test('toJson omits null id and dateTime', () {
      const visit = VisitItem(
        unitLabel: 'A',
        buildingName: 'B',
        dateLabel: 'D',
        status: 'S',
        agent: 'A',
        notes: 'N',
      );
      final json = visit.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('dateTime'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // UnitItem
  // ---------------------------------------------------------------------------
  group('UnitItem', () {
    test('fromJson parses all fields', () {
      final unit = UnitItem.fromJson({
        'id': 'u1',
        'buildingId': 'b1',
        'label': 'A-101',
        'description': '2 ½',
        'bedrooms': 1,
        'rentCents': 850,
        'status': 'occupied',
        'leaseEnd': '2024-12-31',
        'tenant': 'Jean Dupont',
        'amenities': ['fridge', 'stove'],
      });

      expect(unit.id, 'u1');
      expect(unit.buildingId, 'b1');
      expect(unit.number, 'A-101');
      expect(unit.type, '2 ½');
      expect(unit.bedrooms, 1);
      expect(unit.rent, 850);
      expect(unit.tenant, 'Jean Dupont');
      expect(unit.amenities, ['fridge', 'stove']);
    });

    test('fromJson uses defaults', () {
      final unit = UnitItem.fromJson({});
      expect(unit.id, isNull);
      expect(unit.buildingId, isNull);
      expect(unit.amenities, isNull);
      expect(unit.tenant, isNull);
      expect(unit.bedrooms, 0);
      expect(unit.rent, 0);
    });

    test('fromJson handles numeric fields as doubles', () {
      final unit = UnitItem.fromJson({
        'bedrooms': 2.0,
        'rentCents': 1000.5,
      });
      expect(unit.bedrooms, 2);
      expect(unit.rent, 1000);
    });

    test('toJson round-trips', () {
      const original = UnitItem(
        id: 'u1',
        buildingId: 'b1',
        number: 'A-101',
        type: '2 ½',
        bedrooms: 1,
        rent: 850,
        status: 'occupied',
        leaseEnd: '2024-12-31',
        tenant: 'Jean',
        amenities: ['fridge'],
      );

      final restored = UnitItem.fromJson(original.toJson());
      expect(restored.id, 'u1');
      expect(restored.amenities, ['fridge']);
      expect(restored.tenant, 'Jean');
    });

    test('toJson omits nullable fields when null', () {
      const unit = UnitItem(
        number: 'A',
        type: 'T',
        bedrooms: 0,
        rent: 0,
        status: 'S',
        leaseEnd: '',
      );
      final json = unit.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('buildingId'), isFalse);
      // tenant is always included in toJson (no conditional guard)
      expect(json['tenant'], isNull);
      // amenities is omitted when null (converted to Map only if non-null)
      expect(json.containsKey('amenities'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // BuildingItem
  // ---------------------------------------------------------------------------
  group('BuildingItem', () {
    test('fromJson parses all fields', () {
      final building = BuildingItem.fromJson({
        'id': 'b1',
        'name': 'Tour Eiffel',
        'address': '123 Rue',
        'city': 'Montreal',
        'totalUnits': 10,
        'occupiedUnits': 8,
        'monthlyRevenue': 8000,
        'description': 'A building',
        'properties': {'key': 'value'},
        'units': [
          {
            'label': 'A-101',
            'description': '2 ½',
            'bedrooms': 1,
            'rentCents': 850,
            'status': 'occupied',
            'leaseEnd': '2024-12-31',
          },
        ],
      });

      expect(building.id, 'b1');
      expect(building.name, 'Tour Eiffel');
      expect(building.totalUnits, 10);
      expect(building.occupiedUnits, 8);
      expect(building.monthlyRevenue, 8000);
      expect(building.description, 'A building');
      expect(building.properties, {'key': 'value'});
      expect(building.units, hasLength(1));
      expect(building.units.first.number, 'A-101');
    });

    test('fromJson uses defaults', () {
      final building = BuildingItem.fromJson({});
      expect(building.id, isNull);
      expect(building.description, isNull);
      expect(building.properties, isNull);
      expect(building.name, isEmpty);
      expect(building.totalUnits, 0);
      expect(building.units, isEmpty);
    });

    test('occupancyRate calculates correctly', () {
      const full = BuildingItem(
        name: 'A',
        address: 'B',
        city: 'C',
        totalUnits: 10,
        occupiedUnits: 8,
        monthlyRevenue: 0,
        units: [],
      );
      expect(full.occupancyRate, 0.8);
    });

    test('occupancyRate returns 0 when totalUnits is 0', () {
      const empty = BuildingItem(
        name: 'A',
        address: 'B',
        city: 'C',
        totalUnits: 0,
        occupiedUnits: 0,
        monthlyRevenue: 0,
        units: [],
      );
      expect(empty.occupancyRate, 0.0);
    });

    test('toJson round-trips', () {
      const original = BuildingItem(
        id: 'b1',
        name: 'Tour',
        address: '123 Rue',
        city: 'MTL',
        totalUnits: 10,
        occupiedUnits: 8,
        monthlyRevenue: 8000,
        description: 'A building',
        properties: {'key': 'value'},
        units: [
          UnitItem(
            number: 'A-101',
            type: '2 ½',
            bedrooms: 1,
            rent: 850,
            status: 'occupied',
            leaseEnd: '2024-12-31',
          ),
        ],
      );

      final restored = BuildingItem.fromJson(original.toJson());
      expect(restored.id, 'b1');
      expect(restored.occupancyRate, 0.8);
      expect(restored.units.first.number, 'A-101');
    });
  });

  // ---------------------------------------------------------------------------
  // LeadItem
  // ---------------------------------------------------------------------------
  group('LeadItem', () {
    test('fromJson parses all fields', () {
      final lead = LeadItem.fromJson({
        'id': 'l1',
        'fullName': 'Marie Curie',
        'email': 'marie@example.com',
        'phone': '514-555-0100',
        'desiredUnit': '2 ½',
        'budgetCents': 1000,
        'source': 'web',
        'stage': 'qualifie',
        'notes': 'Interested',
        'tags': ['urgent', 'pet'],
        'lastContact': '2024-01-15',
        'offers': [
          {'id': 'o1', 'amount': 1000, 'status': 'active', 'sentAt': '2024-01-15'},
        ],
        'language': 'fr',
        'createdAt': '2024-01-10T08:00:00Z',
      });

      expect(lead.id, 'l1');
      expect(lead.fullName, 'Marie Curie');
      expect(lead.email, 'marie@example.com');
      expect(lead.budget, 1000);
      expect(lead.stage, LeadStage.qualifie);
      expect(lead.tags, ['urgent', 'pet']);
      expect(lead.offers, hasLength(1));
      expect(lead.offers.first.id, 'o1');
      expect(lead.language, 'fr');
      expect(lead.createdAt, DateTime.utc(2024, 1, 10, 8));
    });

    test('fromJson uses defaults', () {
      final lead = LeadItem.fromJson({});
      expect(lead.id, isNull);
      expect(lead.language, isNull);
      expect(lead.createdAt, isNull);
      expect(lead.fullName, isEmpty);
      expect(lead.stage, LeadStage.nouveau);
      expect(lead.tags, isEmpty);
      expect(lead.offers, isEmpty);
      expect(lead.budget, 0);
    });

    test('fromJson handles budget as double', () {
      final lead = LeadItem.fromJson({'budgetCents': 1000.5});
      expect(lead.budget, 1000);
    });

    test('fromJson parses stage with unknown value', () {
      final lead = LeadItem.fromJson({'stage': 'unknown'});
      expect(lead.stage, LeadStage.nouveau);
    });

    test('toJson round-trips', () {
      final original = LeadItem(
        id: 'l1',
        fullName: 'Marie',
        email: 'marie@example.com',
        phone: '514',
        desiredUnit: '2 ½',
        budget: 1000,
        source: 'web',
        stage: LeadStage.negociation,
        notes: 'N',
        tags: ['urgent'],
        lastContact: '2024-01-15',
        offers: const [
          OfferItem(id: 'o1', amount: 1000, status: 'active', sentAt: ''),
        ],
        language: 'fr',
        createdAt: DateTime.utc(2024, 1, 10),
      );

      final restored = LeadItem.fromJson(original.toJson());
      expect(restored.id, 'l1');
      expect(restored.stage, LeadStage.negociation);
      expect(restored.stage.name, 'negociation');
      expect(restored.tags, ['urgent']);
      expect(restored.offers.first.id, 'o1');
      expect(restored.language, 'fr');
    });

    test('toJson omits nullable fields when null', () {
      const lead = LeadItem(
        fullName: 'X',
        email: 'X',
        phone: 'X',
        desiredUnit: 'X',
        budget: 0,
        source: 'X',
        stage: LeadStage.nouveau,
        notes: 'X',
        tags: [],
        lastContact: 'X',
        offers: [],
      );
      final json = lead.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('language'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
    });
  });
}
