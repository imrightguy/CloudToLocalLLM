import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:immogestion/screens/renovation_ops_screen.dart';
import 'package:immogestion/services/api_service.dart';

void main() {
  setUp(() {
    ApiService.instance.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/renovation-job-templates')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'template-1',
                'name': 'Peinture finale',
                'description': 'Finition murs et moulures',
                'isFavorite': true,
                'materials': ['Paint', 'Primer', 'Rollers'],
                'notes': 'Order paint before weekend',
                'manualProductLinks': [
                  {'label': 'Home Depot', 'url': 'https://example.com/paint'},
                ],
                'suggestedMissingItems': ['Painter\'s tape', 'Drop cloth'],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/buildings')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'building-1',
                'name': 'Place Du Parc',
                'address': '123 rue des Pins',
                'city': 'Montréal',
                'totalUnits': 10,
                'occupiedUnits': 8,
                'monthlyRevenue': 12345,
                'units': [],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (path.endsWith('/buildings/units') && request.url.queryParameters['buildingId'] == 'building-1') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'id': 'unit-1',
                'buildingId': 'building-1',
                'number': '304',
                'type': '3 1/2',
                'bedrooms': 1,
                'bathrooms': 1,
                'rent': 145000,
                'status': 'vacant',
                'leaseEnd': '',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
    });
  });

  testWidgets('shows renovation ops shell sections', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rénovation Ops'), findsOneWidget);
    expect(find.text('Module séparé du Leasing'), findsOneWidget);
    expect(find.text('Modèles de travaux'), findsOneWidget);
    expect(find.text('Flux de travail'), findsOneWidget);
    expect(find.text('Hooks prévus'), findsOneWidget);
    expect(find.text('Peinture finale'), findsOneWidget);
    expect(find.text('Prêt pour Leasing'), findsWidgets);
  });

  testWidgets('opens apartment detail sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Logement 304'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logement 304'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Détail du logement 304'), findsOneWidget);
    expect(find.text('Tâches'), findsOneWidget);
    expect(find.text('Bloqueur principal'), findsOneWidget);
  });

  testWidgets('opens the mobile photo capture sheet from apartment detail', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Logement 304'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logement 304'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Téléverser une photo'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Téléverser une photo'));
    await tester.pumpAndSettle();

    expect(find.text('Téléverser une photo terrain'), findsOneWidget);
    expect(find.text('Choisir une photo'), findsOneWidget);
    expect(find.text('Logement 304'), findsWidgets);
  });
}
