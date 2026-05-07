import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:immogestion/screens/renovation_ops_screen.dart';
import 'package:immogestion/screens/tenant_checklist_operator_screen.dart';
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

      if (path == '/api/tenant-checklists/start' || path.endsWith('/tenant-checklists/start')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'session': {
                'id': 'session-12345678',
                'unitId': 'unit-304',
                'leaseId': 'lease-304-a',
                'checklistType': 'move_in',
                'state': 'in_progress',
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
              'unit': {
                'id': 'unit-304',
                'label': '304',
              },
              'lease': {
                'id': 'lease-304-a',
              },
              'steps': [
                {
                  'id': 'step-1',
                  'stepKey': 'identity_unit_confirmation',
                  'stepOrder': 1,
                  'title': 'Confirmation de l’unité',
                  'description': 'Confirmer l’identité du locataire et l’unité concernée.',
                  'status': 'pending',
                  'requiredFields': ['tenantName', 'unitLabel'],
                  'metadata': {},
                },
              ],
              'attachments': [],
              'signatures': [],
              'events': [],
              'summary': {
                'stepCount': 1,
                'completedStepCount': 0,
                'blockedStepCount': 0,
                'pendingStepCount': 1,
                'skippedStepCount': 0,
                'attachmentCount': 0,
                'signatureCount': 0,
                'eventCount': 0,
                'isComplete': false,
                'isPaused': false,
                'lastEventAt': null,
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/tenant-checklists/session-12345678/summary') || path.endsWith('/tenant-checklists/session-12345678/manager-summary')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'session': {
                'id': 'session-12345678',
                'unitId': 'unit-304',
                'leaseId': 'lease-304-a',
                'checklistType': 'move_in',
                'state': 'in_progress',
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
              'unit': {'id': 'unit-304', 'label': '304'},
              'lease': {'id': 'lease-304-a'},
              'steps': [
                {
                  'id': 'step-1',
                  'stepKey': 'identity_unit_confirmation',
                  'stepOrder': 1,
                  'title': 'Confirmation de l’unité',
                  'description': 'Confirmer l’identité du locataire et l’unité concernée.',
                  'status': 'pending',
                  'requiredFields': ['tenantName', 'unitLabel'],
                  'metadata': {},
                },
              ],
              'attachments': [],
              'signatures': [],
              'events': [],
              'summary': {
                'stepCount': 1,
                'completedStepCount': 0,
                'blockedStepCount': 0,
                'pendingStepCount': 1,
                'skippedStepCount': 0,
                'attachmentCount': 0,
                'signatureCount': 0,
                'eventCount': 0,
                'isComplete': false,
                'isPaused': false,
                'lastEventAt': null,
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      if (path.endsWith('/tenant-checklists/session-12345678/pause') || path.endsWith('/tenant-checklists/session-12345678/resume') || path.endsWith('/tenant-checklists/session-12345678/submit')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'session': {
                'id': 'session-12345678',
                'unitId': 'unit-304',
                'leaseId': 'lease-304-a',
                'checklistType': 'move_in',
                'state': 'in_progress',
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
              'unit': {'id': 'unit-304', 'label': '304'},
              'lease': {'id': 'lease-304-a'},
              'steps': [],
              'attachments': [],
              'signatures': [],
              'events': [],
              'summary': {
                'stepCount': 1,
                'completedStepCount': 0,
                'blockedStepCount': 0,
                'pendingStepCount': 1,
                'skippedStepCount': 0,
                'attachmentCount': 0,
                'signatureCount': 0,
                'eventCount': 0,
                'isComplete': false,
                'isPaused': false,
                'lastEventAt': null,
                'currentStepKey': 'identity_unit_confirmation',
                'currentStepOrder': 1,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
    });
  });

  testWidgets('creates and displays a backend-backed tenant checklist session', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TenantChecklistOperatorScreen(
          unitId: 'unit-304',
          unitLabel: '304',
          buildingName: 'Place Du Parc',
          leaseId: 'lease-304-a',
          tenantName: 'Sophie Tremblay',
          tenantPhone: '514 555-1020',
          checklistType: 'move_in',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'Sophie Tremblay');
    await tester.enterText(find.byType(TextField).at(1), '514 555-1020');
    await tester.ensureVisible(find.text('Créer la session'));
    await tester.tap(find.text('Créer la session'));
    await tester.pumpAndSettle();

    expect(find.text('Checklist locataire'), findsOneWidget);
    expect(find.text('Confirmation de l’unité'), findsOneWidget);
    expect(find.textContaining('Session session-12'), findsOneWidget);
    expect(find.text('Résumé gestionnaire'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Étapes 1'), findsOneWidget);
  });

  testWidgets('opens the tenant checklist from renovation ops flow', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Logement 304'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logement 304'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ouvrir la checklist locataire'));
    await tester.tap(find.text('Ouvrir la checklist locataire'));
    await tester.pumpAndSettle();

    expect(find.text('Checklist locataire'), findsOneWidget);
    expect(find.text('Contexte opérateur'), findsOneWidget);
    expect(find.text('Place Du Parc'), findsOneWidget);
  });
}
