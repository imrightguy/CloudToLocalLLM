import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:immogestion/models.dart';
import 'package:immogestion/screens/visit_detail_screen.dart';
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
        onGenerateRoute: _onGenerateRoute,
        home: VisitsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Locataire confirmé'), findsOneWidget);
    final detailsTooltip = find.byTooltip('Ouvrir le détail de la visite de Sarah Tremblay');
    expect(detailsTooltip, findsOneWidget);

    await tester.tap(find.text('Détails').first);
    await tester.pumpAndSettle();

    expect(find.byType(VisitDetailScreen), findsOneWidget);
    expect(find.text('Sarah Tremblay'), findsOneWidget);
    expect(find.text('Visite du ${_visitHeadingLabel()}'), findsOneWidget);
  });
}

Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
  if (settings.name == '/visits/visit-123') {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => VisitDetailScreen(visit: _testVisit()),
    );
  }

  return null;
}

VisitItem _testVisit() {
  return VisitItem.fromJson({
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

String _visitHeadingLabel() {
  return DateFormat('EEEE d MMMM yyyy à HH:mm', 'fr').format(_visitDateTime());
}
