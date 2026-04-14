import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/unit_service.dart';

void main() {
  group('UnitService', () {
    test('singleton instance is stable', () {
      expect(
        identical(UnitService.instance, UnitService.instance),
        true,
      );
    });
  });

  group('VacancyStatus', () {
    test('fromString parses occupied variants', () {
      expect(VacancyStatus.fromString('occupied'), VacancyStatus.occupied);
      expect(VacancyStatus.fromString('Occupied'), VacancyStatus.occupied);
      expect(VacancyStatus.fromString('occupé'), VacancyStatus.occupied);
    });

    test('fromString parses maintenance', () {
      expect(VacancyStatus.fromString('maintenance'), VacancyStatus.maintenance);
      expect(VacancyStatus.fromString('Maintenance'), VacancyStatus.maintenance);
    });

    test('fromString defaults vacant for unknown values', () {
      expect(VacancyStatus.fromString('available'), VacancyStatus.vacant);
      expect(VacancyStatus.fromString(''), VacancyStatus.vacant);
      expect(VacancyStatus.fromString('foo'), VacancyStatus.vacant);
    });

    test('labels are in French', () {
      expect(VacancyStatus.vacant.label, 'Libre');
      expect(VacancyStatus.occupied.label, 'Occupé');
      expect(VacancyStatus.maintenance.label, 'Maintenance');
    });

    test('colors are distinct', () {
      expect(VacancyStatus.vacant.color, const Color(0xFFF59E0B));
      expect(VacancyStatus.occupied.color, const Color(0xFF10B981));
      expect(VacancyStatus.maintenance.color, const Color(0xFFEF4444));
    });
  });

  group('UnitItem with bathrooms', () {
    test('fromJson parses bathrooms', () {
      final json = {
        'label': '4A',
        'bedrooms': 2,
        'bathrooms': 1,
        'rentCents': 120000,
        'status': 'occupied',
        'tenantName': 'Jean Dupont',
        'tenantPhone': '(514) 555-1234',
        'tenantLeaseEnd': '2027-01-01',
        'amenities': {'fridge': true, 'stove': true},
        'squareFeet': 800,
      };

      final unit = UnitItem.fromJson(json);
      expect(unit.number, '4A');
      expect(unit.bedrooms, 2);
      expect(unit.bathrooms, 1);
      expect(unit.rent, 120000);
      expect(unit.vacancyStatus, VacancyStatus.occupied);
      expect(unit.tenantName, 'Jean Dupont');
      expect(unit.tenantPhone, '(514) 555-1234');
      expect(unit.amenities, ['fridge', 'stove']);
      expect(unit.squareFeet, 800);
    });

    test('fromJson defaults bathrooms to 0 when missing', () {
      final json = {
        'label': '1A',
        'bedrooms': 1,
        'rentCents': 90000,
        'status': 'available',
      };

      final unit = UnitItem.fromJson(json);
      expect(unit.bathrooms, 0);
      expect(unit.vacancyStatus, VacancyStatus.vacant);
    });

    test('toJson includes bathrooms', () {
      const unit = UnitItem(
        number: '3B',
        type: '2 1/2',
        bedrooms: 1,
        bathrooms: 1,
        rent: 95000,
        status: 'occupied',
        leaseEnd: '2027-06-30',
        tenantName: 'Marie Tremblay',
      );

      final json = unit.toJson();
      expect(json['bathrooms'], 1);
      expect(json['bedrooms'], 1);
      expect(json['label'], '3B');
    });

    test('vacancyStatus derived from status field', () {
      final occupied = UnitItem(
        number: '1',
        type: '',
        bedrooms: 0,
        bathrooms: 0,
        rent: 0,
        status: 'occupied',
        leaseEnd: '',
      );
      expect(occupied.vacancyStatus, VacancyStatus.occupied);

      final vacant = UnitItem(
        number: '2',
        type: '',
        bedrooms: 0,
        bathrooms: 0,
        rent: 0,
        status: 'available',
        leaseEnd: '',
      );
      expect(vacant.vacancyStatus, VacancyStatus.vacant);

      final maintenance = UnitItem(
        number: '3',
        type: '',
        bedrooms: 0,
        bathrooms: 0,
        rent: 0,
        status: 'maintenance',
        leaseEnd: '',
      );
      expect(maintenance.vacancyStatus, VacancyStatus.maintenance);
    });
  });
}
