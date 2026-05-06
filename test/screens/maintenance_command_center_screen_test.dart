import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:immogestion/screens/maintenance_command_center_screen.dart';
import 'package:immogestion/services/api_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr', null);
    await initializeDateFormatting('fr_CA', null);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MaintenanceCommandCenterScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    ApiService.instance.client = MockClient((request) async {
      if (request.url.path.endsWith('/maintenance/command-center')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'summary': {
                'propertyCount': 1,
                'renovationCount': 2,
                'blockedCount': 1,
                'readyCount': 1,
                'overdueTaskCount': 3,
                'dueSoonTaskCount': 4,
                'openOrderCount': 5,
                'pendingIntakeCount': 6,
                'dispatchableEmployeeCount': 7,
                'tenantMessageSentCount': 8,
                'tenantMessageFailedCount': 1,
                'tenantMessagePendingCount': 2,
              },
              'properties': [
                {
                  'buildingId': 'building-1',
                  'buildingName': 'Place du Parc',
                  'unitCount': 10,
                  'renovationCount': 2,
                  'blockedCount': 1,
                  'readyCount': 1,
                  'overdueTaskCount': 3,
                  'dueSoonTaskCount': 4,
                  'openOrderCount': 5,
                  'pendingIntakeCount': 6,
                  'tenantMessageStats': {
                    'total': 3,
                    'sent': 2,
                    'failed': 1,
                    'latestAt': '2026-05-06T00:15:00.000Z',
                  },
                  'capacity': {
                    'candidateCount': 4,
                    'dispatchableCount': 2,
                    'totalOpenTasks': 6,
                    'buildingOpenTasks': 2,
                  },
                  'backlog': [
                    {
                      'id': 'reno-1',
                      'unitId': 'unit-1',
                      'buildingId': 'building-1',
                      'unitLabel': '304',
                      'buildingName': 'Place du Parc',
                      'phase': 'blocked',
                      'readiness': '71 % prêt',
                      'taskCount': 8,
                      'doneCount': 5,
                      'blockerCount': 1,
                      'overdueTaskCount': 1,
                      'dueSoonTaskCount': 1,
                      'nextStep': 'Peinture finale et inspection cuisine',
                      'updatedAt': '2026-05-06T00:20:00.000Z',
                      'blockerNote': 'Attente d’un luminaire pour le salon',
                      'nextDueAt': '2026-05-07T00:00:00.000Z',
                      'assignedEmployeeLabel': 'Alice Smith',
                      'tenantPhone': '+15145550111',
                      'tenantMessageStatus': {
                        'status': 'sent',
                        'lastSentAt': '2026-05-06T00:05:00.000Z',
                        'phoneNumber': '+15145550111',
                        'errorMessage': null,
                      },
                    },
                  ],
                  'nextDueAt': '2026-05-07T00:00:00.000Z',
                },
              ],
              'backlog': [
                {
                  'id': 'reno-1',
                  'unitId': 'unit-1',
                  'buildingId': 'building-1',
                  'unitLabel': '304',
                  'buildingName': 'Place du Parc',
                  'phase': 'blocked',
                  'readiness': '71 % prêt',
                  'taskCount': 8,
                  'doneCount': 5,
                  'blockerCount': 1,
                  'overdueTaskCount': 1,
                  'dueSoonTaskCount': 1,
                  'nextStep': 'Peinture finale et inspection cuisine',
                  'updatedAt': '2026-05-06T00:20:00.000Z',
                  'blockerNote': 'Attente d’un luminaire pour le salon',
                  'nextDueAt': '2026-05-07T00:00:00.000Z',
                  'assignedEmployeeLabel': 'Alice Smith',
                  'tenantPhone': '+15145550111',
                  'tenantMessageStatus': {
                    'status': 'sent',
                    'lastSentAt': '2026-05-06T00:05:00.000Z',
                    'phoneNumber': '+15145550111',
                    'errorMessage': null,
                  },
                },
              ],
              'tenantMessages': [
                {
                  'renovationId': 'reno-1',
                  'unitId': 'unit-1',
                  'buildingId': 'building-1',
                  'buildingName': 'Place du Parc',
                  'unitLabel': '304',
                  'tenantPhone': '+15145550111',
                  'status': 'sent',
                  'lastSentAt': '2026-05-06T00:05:00.000Z',
                  'phoneNumber': '+15145550111',
                  'errorMessage': null,
                },
              ],
              'asOf': '2026-05-06T00:00:00.000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      if (request.url.path.endsWith('/maintenance/command-center-empty')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'summary': {
                'propertyCount': 0,
                'renovationCount': 0,
                'blockedCount': 0,
                'readyCount': 0,
                'overdueTaskCount': 0,
                'dueSoonTaskCount': 0,
                'openOrderCount': 0,
                'pendingIntakeCount': 0,
                'dispatchableEmployeeCount': 0,
                'tenantMessageSentCount': 0,
                'tenantMessageFailedCount': 0,
                'tenantMessagePendingCount': 0,
              },
              'properties': [],
              'backlog': [],
              'tenantMessages': [],
              'asOf': '2026-05-06T00:00:00.000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }

      return http.Response(
        jsonEncode({'message': 'boom'}),
        500,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });

  testWidgets('renders the maintenance command center shell', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Place du Parc'), findsOneWidget);
    expect(find.textContaining('304'), findsWidgets);
    expect(find.text('Messages locataires'), findsOneWidget);
    expect(find.text('Envoyé'), findsWidgets);
    expect(find.text('Dispatchables'), findsOneWidget);
  });

  testWidgets('shows an empty state when the command center has no data', (tester) async {
    ApiService.instance.client = MockClient((request) async {
      if (request.url.path.endsWith('/maintenance/command-center')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'summary': {
                'propertyCount': 0,
                'renovationCount': 0,
                'blockedCount': 0,
                'readyCount': 0,
                'overdueTaskCount': 0,
                'dueSoonTaskCount': 0,
                'openOrderCount': 0,
                'pendingIntakeCount': 0,
                'dispatchableEmployeeCount': 0,
                'tenantMessageSentCount': 0,
                'tenantMessageFailedCount': 0,
                'tenantMessagePendingCount': 0,
              },
              'properties': [],
              'backlog': [],
              'tenantMessages': [],
              'asOf': '2026-05-06T00:00:00.000Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(jsonEncode({'message': 'unexpected'}), 500);
    });

    await pumpScreen(tester);

    expect(find.text('Aucune donnée de maintenance disponible'), findsOneWidget);
    expect(find.text('Rafraîchir'), findsOneWidget);
  });

  testWidgets('shows an error state when the command center request fails', (tester) async {
    ApiService.instance.client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'boom'}),
        500,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await pumpScreen(tester);

    expect(find.textContaining('Impossible de charger le tableau de bord'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
  });
}
