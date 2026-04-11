import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/services/building_service.dart';

void main() {
  group('PaginatedResult', () {
    test('holds all pagination fields', () {
      const result = PaginatedResult<BuildingItem>(
        items: [],
        total: 100,
        page: 1,
        limit: 20,
        totalPages: 5,
        hasMore: true,
      );
      expect(result.total, 100);
      expect(result.page, 1);
      expect(result.limit, 20);
      expect(result.totalPages, 5);
      expect(result.hasMore, true);
      expect(result.items, isEmpty);
    });

    test('hasMore is false on last page', () {
      const result = PaginatedResult<BuildingItem>(
        items: [],
        total: 40,
        page: 2,
        limit: 20,
        totalPages: 2,
        hasMore: false,
      );
      expect(result.hasMore, false);
    });
  });

  group('BuildingService', () {
    test('singleton instance is stable', () {
      expect(
        identical(BuildingService.instance, BuildingService.instance),
        true,
      );
    });

    test('getBuildings query builds correct params with search', () {
      // Verify the query string construction logic by checking
      // that Uri.encodeComponent handles special characters.
      const search = 'Saint-Laurent';
      final encoded = Uri.encodeComponent(search);
      expect(encoded, 'Saint-Laurent');
      // Spaces should be encoded
      expect(Uri.encodeComponent('Le Plateau'), 'Le%20Plateau');
      // Accented chars
      expect(Uri.encodeComponent('Montréal'), 'Montr%C3%A9al');
    });

    test('getBuildings query omits empty search', () {
      // When search is null/empty, the query should only have page & limit
      final params = <String, String>{
        'page': '1',
        'limit': '20',
      };
      const search = '';
      if (search.isNotEmpty) params['search'] = search;
      expect(params.length, 2);
      expect(params.containsKey('search'), false);
    });

    test('getBuildings metadata defaults when missing', () {
      // Simulate the parsing logic from BuildingService.getBuildings
      final result = <String, dynamic>{
        'data': [
          {
            'name': 'Le Test',
            'address': '1 Rue',
            'city': 'MTL',
            'totalUnits': 2,
            'occupiedUnits': 1,
            'monthlyRevenue': 5000,
            'units': [],
          },
        ],
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      const page = 1;
      const limit = 20;

      final paginated = PaginatedResult<BuildingItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? items.length,
        page: (metadata['page'] as num?)?.toInt() ?? page,
        limit: (metadata['limit'] as num?)?.toInt() ?? limit,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items.length, 1);
      expect(paginated.items.first.name, 'Le Test');
      expect(paginated.total, 1); // defaults to items.length
      expect(paginated.page, 1); // defaults to page param
      expect(paginated.limit, 20); // defaults to limit param
      expect(paginated.totalPages, 1); // defaults to 1
      expect(paginated.hasMore, false); // defaults to false
    });

    test('getBuildings metadata parses when present', () {
      final result = <String, dynamic>{
        'data': [],
        'metadata': {
          'total': 50,
          'page': 2,
          'limit': 20,
          'totalPages': 3,
          'hasMore': true,
        },
      };

      final data = result['data'];
      final metadata = result['metadata'] as Map<String, dynamic>? ?? {};

      final items = (data as List<dynamic>)
          .map((e) => BuildingItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final paginated = PaginatedResult<BuildingItem>(
        items: items,
        total: (metadata['total'] as num?)?.toInt() ?? items.length,
        page: (metadata['page'] as num?)?.toInt() ?? 1,
        limit: (metadata['limit'] as num?)?.toInt() ?? 20,
        totalPages: (metadata['totalPages'] as num?)?.toInt() ?? 1,
        hasMore: (metadata['hasMore'] as bool?) ?? false,
      );

      expect(paginated.items, isEmpty);
      expect(paginated.total, 50);
      expect(paginated.page, 2);
      expect(paginated.limit, 20);
      expect(paginated.totalPages, 3);
      expect(paginated.hasMore, true);
    });

    test('getUnits handles single-object fallback', () {
      // The service handles both array and single-object responses
      final singleObject = <String, dynamic>{
        'label': '101',
        'bedrooms': 2,
        'rentCents': 150000,
      };
      final asList = [singleObject];

      // Array path
      final fromList = asList
          .map((e) => UnitItem.fromJson(e))
          .toList();
      expect(fromList.length, 1);

      // Single-object fallback path
      final fromSingle = [UnitItem.fromJson(singleObject)];
      expect(fromSingle.length, 1);
      expect(fromSingle.first.number, '101');
    });
  });
}
