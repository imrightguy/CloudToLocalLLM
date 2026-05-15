import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:immogestion/screens/visits_screen.dart';
import 'package:immogestion/services/api_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  setUp(() {
    ApiService.instance.client = MockClient(_handleMockRequest);
  });

  tearDown(() {
    ApiService.instance.client.close();
    ApiService.instance.client = http.Client();
  });

  testWidgets('visit cards open the visit detail route', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VisitsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Locataire confirmé', skipOffstage: false),
        findsOneWidget);
    final detailsButton = find
        .widgetWithText(OutlinedButton, 'Détails', skipOffstage: false)
        .first;
    await tester.ensureVisible(detailsButton);

    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.text('Détails de la visite'), findsOneWidget);
    expect(find.text('Sarah Tremblay', skipOffstage: false), findsOneWidget);
    expect(find.textContaining('Locataire confirmé', skipOffstage: false),
        findsOneWidget);
    expect(
        find.text('Employé confirmé: ', skipOffstage: false), findsOneWidget);
  });
}

Future<http.Response> _handleMockRequest(http.Request request) async {
  if (request.url.path == '/api/visits') {
    return http.Response(
      jsonEncode({
        'success': true,
        'data': [
          {
            'id': 'visit-123',
            'leadId': 'lead-123',
            'leadName': 'Sarah Tremblay',
            'unitLabel': '101',
            'buildingName': 'Résidence du Parc',
            'dateTime': _visitDateTime().toIso8601String(),
            'status': 'confirmed',
            'agent': 'Marie Côté',
            'notes': 'Apportez une pièce d\'identité.',
            'tenantConfirmed': true,
            'employeeConfirmed': true,
            'occupantNotified': true,
            'morningOfSent': true,
            'morningReminderSentAt': '2026-06-11T07:00:00.000',
          },
        ],
        'metadata': {
          'page': 1,
          'limit': 20,
          'total': 1,
          'totalPages': 1,
          'hasMore': false,
        },
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  if (request.url.path == '/api/visits/visit-123') {
    return http.Response(
      jsonEncode({
        'success': true,
        'data': {
          'id': 'visit-123',
          'leadId': 'lead-123',
          'leadName': 'Sarah Tremblay',
          'unitLabel': '101',
          'buildingName': 'Résidence du Parc',
          'dateTime': _visitDateTime().toIso8601String(),
          'status': 'confirmed',
          'agent': 'Marie Côté',
          'notes': 'Apportez une pièce d\'identité.',
          'tenantConfirmed': true,
          'tenantConfirmedAt': '2026-06-11T12:00:00.000',
          'employeeConfirmed': true,
          'employeeConfirmedAt': '2026-06-11T12:05:00.000',
          'occupantNotified': true,
          'morningOfSent': true,
          'morningReminderSentAt': '2026-06-11T07:00:00.000',
        },
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }

  return http.Response('Not found', 404);
}

DateTime _visitDateTime() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 14, 0);
}
