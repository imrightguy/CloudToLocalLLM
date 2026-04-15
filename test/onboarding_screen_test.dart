import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/screens/onboarding_screen.dart';

void main() {
  group('OnboardingData', () {
    test('default values are empty', () {
      final data = OnboardingData(
        buildingName: '',
        buildingAddress: '',
        buildingCity: 'Montréal',
        totalUnits: 0,
      );
      expect(data.buildingId, '');
      expect(data.buildingName, '');
      expect(data.buildingAddress, '');
      expect(data.buildingCity, 'Montréal');
      expect(data.totalUnits, 0);
      expect(data.units, isEmpty);
    });

    test('units defaults to empty list when null', () {
      final data = OnboardingData(
        buildingName: 'Test',
        buildingAddress: '123 St-Catherine',
        buildingCity: 'Montréal',
        totalUnits: 2,
      );
      expect(data.units, isEmpty);
    });

    test('units can be provided', () {
      final units = [
        {'label': '1', 'type': 'Studio', 'bedrooms': 1, 'rentCents': 80000},
        {'label': '2', 'type': '4½', 'bedrooms': 2, 'rentCents': 120000},
      ];
      final data = OnboardingData(
        buildingName: 'Test',
        buildingAddress: '123 St-Catherine',
        buildingCity: 'Montréal',
        totalUnits: 2,
        units: units,
      );
      expect(data.units.length, 2);
      expect(data.units[0]['label'], '1');
    });

    test('mutable fields can be updated', () {
      final data = OnboardingData(
        buildingName: '',
        buildingAddress: '',
        buildingCity: 'Montréal',
        totalUnits: 0,
      );
      data.buildingId = 'bld-123';
      data.buildingName = 'Immeuble A';
      data.totalUnits = 5;
      data.units = [{'label': '1'}];

      expect(data.buildingId, 'bld-123');
      expect(data.buildingName, 'Immeuble A');
      expect(data.totalUnits, 5);
      expect(data.units.length, 1);
    });
  });
}
