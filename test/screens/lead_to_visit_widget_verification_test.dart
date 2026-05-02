import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:immogestion/screens/conversation_detail_screen.dart';
import 'package:immogestion/screens/sms_conversation_screen.dart';
import 'package:immogestion/screens/visit_form_screen.dart';
import 'package:immogestion/services/api_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_CA');
  });

  setUp(() {
    ApiService.instance.client = MockClient(_handleMockRequest);
  });

  tearDown(() {
    ApiService.instance.client.close();
    ApiService.instance.client = http.Client();
  });

  group('Marketplace lead-to-visit widget verification', () {
    testWidgets(
      'ConversationDetailScreen opens VisitFormScreen with the source contact id',
      (tester) async {
        const contactId = 'lead-123';

        await tester.pumpWidget(
          const MaterialApp(
            home: ConversationDetailScreen(
              contactId: contactId,
              contactName: 'Sarah Tremblay',
              contactPhone: '+1 514 555-0101',
              contactInitials: 'ST',
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Planifier une visite'));
        await tester.pumpAndSettle();

        expect(find.byType(VisitFormScreen), findsOneWidget);

        final visitForm =
            tester.widget<VisitFormScreen>(find.byType(VisitFormScreen));
        expect(visitForm.initialLeadId, contactId);
      },
    );

    testWidgets(
      'SmsConversationScreen opens VisitFormScreen with the source contact id',
      (tester) async {
        const contactId = 'lead-456';

        await tester.pumpWidget(
          const MaterialApp(
            home: SmsConversationScreen(
              contactId: contactId,
              contactName: 'Marc Gagnon',
              contactPhone: '+1 438 555-0102',
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Planifier une visite'));
        await tester.pumpAndSettle();

        expect(find.byType(VisitFormScreen), findsOneWidget);

        final visitForm =
            tester.widget<VisitFormScreen>(find.byType(VisitFormScreen));
        expect(visitForm.initialLeadId, contactId);
      },
    );

    testWidgets(
      'VisitFormScreen preselects the original lead when the API returns it',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: VisitFormScreen(initialLeadId: 'lead-123'),
          ),
        );

        await tester.pumpAndSettle();

        final leadField = find.byWidgetPredicate(
          (widget) =>
              widget is DropdownButtonFormField<String> &&
              widget.decoration.labelText == 'Prospect *',
        );

        expect(leadField, findsOneWidget);
        final dropdown =
            tester.widget<DropdownButtonFormField<String>>(leadField);
        expect(dropdown.initialValue, 'lead-123');
      },
    );
  });
}

Future<http.Response> _handleMockRequest(http.Request request) async {
  final path = request.url.path;

  if (path.contains('/communications/logs') ||
      path.contains('/sms/conversation/')) {
    return _jsonResponse({'success': true, 'data': []});
  }

  if (path.contains('/buildings/units')) {
    return _jsonResponse({
      'success': true,
      'data': [
        {
          'id': 'unit-101',
          'label': '101',
          'description': '3 1/2',
          'bedrooms': 1,
          'bathrooms': 1,
          'rentCents': 150000,
          'status': 'vacant',
          'leaseEnd': '2026-12-31',
        },
      ],
    });
  }

  if (path.contains('/leads')) {
    return _jsonResponse({
      'success': true,
      'data': [
        {
          'id': 'lead-123',
          'fullName': 'Alex Tremblay',
          'email': 'alex@example.com',
          'phone': '5145550101',
          'desiredUnit': '101',
          'budgetCents': 150000,
          'source': 'marketplace',
          'stage': 'nouveau',
          'notes': '',
          'tags': const [],
          'lastContact': '',
          'offers': const [],
        },
        {
          'id': 'lead-456',
          'fullName': 'Marie Côté',
          'email': 'marie@example.com',
          'phone': '4385550199',
          'desiredUnit': '101',
          'budgetCents': 150000,
          'source': 'sms',
          'stage': 'contacte',
          'notes': '',
          'tags': const [],
          'lastContact': '',
          'offers': const [],
        },
      ],
    });
  }

  if (path.contains('/employees')) {
    return _jsonResponse({
      'success': true,
      'data': [
        {
          'id': 'emp-1',
          'firstName': 'Marie',
          'lastName': 'Côté',
          'email': 'marie@example.com',
          'phone': '4385550199',
          'isActive': true,
          'buildingAssignments': const [],
        },
      ],
    });
  }

  if (path.contains('/visits')) {
    return _jsonResponse({
      'success': true,
      'data': const [],
      'metadata': {
        'page': 1,
        'limit': 100,
        'total': 0,
        'totalPages': 1,
        'hasMore': false,
      },
    });
  }

  return http.Response('Not found: ${request.method} ${request.url}', 404);
}

http.Response _jsonResponse(Map<String, dynamic> body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: const {'content-type': 'application/json'},
  );
}
