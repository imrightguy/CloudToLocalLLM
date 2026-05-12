import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:immogestion/screens/renovation_ops_screen.dart';
import 'package:immogestion/services/api_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr', null);
  });

  tearDown(() {
    ApiService.instance.client.close();
    ApiService.instance.client = http.Client();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RenovationOpsScreen(),
      ),
    );
  }

  MockClient buildClient({
    required Map<String, dynamic> commandCenter,
    Map<String, dynamic>? renovation,
    Map<String, dynamic>? lease,
    int statusCode = 200,
  }) {
    return MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/maintenance/command-center')) {
        return http.Response(
          jsonEncode({'success': true, 'data': commandCenter}),
          statusCode,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path.endsWith('/renovations/reno-1')) {
        return http.Response(
          jsonEncode({'success': true, 'data': renovation ?? const {}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (path.endsWith('/leases/unit/unit-1')) {
        return http.Response(
          jsonEncode({'success': true, 'data': lease ?? const {}}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({'message': 'unexpected route', 'path': path}),
        404,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  testWidgets('shows a loading indicator before the live dashboard resolves', (tester) async {
    final completer = Completer<http.Response>();
    ApiService.instance.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/maintenance/command-center')) {
        return completer.future;
      }
      return http.Response(jsonEncode({'message': 'unexpected'}), 404);
    });

    await pumpScreen(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(
      http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'summary': {
              'propertyCount': 1,
              'renovationCount': 1,
              'blockedCount': 1,
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
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('renders a live renovation apartment card from API data', (tester) async {
    ApiService.instance.client = buildClient(
      commandCenter: {
        'summary': {
          'propertyCount': 1,
          'renovationCount': 1,
          'blockedCount': 1,
          'readyCount': 0,
          'overdueTaskCount': 2,
          'dueSoonTaskCount': 1,
          'openOrderCount': 0,
          'pendingIntakeCount': 0,
          'dispatchableEmployeeCount': 0,
          'tenantMessageSentCount': 0,
          'tenantMessageFailedCount': 0,
          'tenantMessagePendingCount': 0,
        },
        'properties': [],
        'backlog': [
          {
            'id': 'reno-1',
            'unitId': 'unit-1',
            'buildingId': 'building-1',
            'unitLabel': '304',
            'buildingName': 'Place du Parc',
            'phase': 'blocked',
            'readiness': '71 % prêt',
            'taskCount': 3,
            'doneCount': 2,
            'blockerCount': 1,
            'overdueTaskCount': 1,
            'dueSoonTaskCount': 1,
            'nextStep': 'Peinture finale et inspection cuisine',
            'updatedAt': '2026-05-06T00:20:00.000Z',
            'blockerNote': 'Attente d’un luminaire pour le salon',
            'nextDueAt': '2026-05-07T00:00:00.000Z',
            'assignedEmployeeLabel': 'Alice Smith',
            'tenantPhone': '+151****0111',
            'tenantMessageStatus': {
              'status': 'sent',
              'lastSentAt': '2026-05-06T00:05:00.000Z',
              'phoneNumber': '+151****0111',
              'errorMessage': null,
            },
          },
        ],
        'tenantMessages': [],
        'asOf': '2026-05-06T00:00:00.000Z',
      },
      renovation: {
        'id': 'reno-1',
        'unit': {'id': 'unit-1', 'label': '304'},
        'tasks': [
          {'title': 'Retirer les anciens luminaires', 'status': 'done'},
          {'title': 'Reboucher les trous', 'status': 'done'},
          {'title': 'Peinture des murs', 'status': 'in_progress'},
        ],
        'orders': [],
        'surplus': [],
      },
      lease: {
        'id': 'lease-304-a',
        'unitId': 'unit-1',
        'unitLabel': '304',
        'tenantName': 'Sophie Tremblay',
        'tenantPhone': '514 555-1020',
        'buildingName': 'Place du Parc',
      },
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Appartements actifs'), findsOneWidget);
    expect(find.text('Bloqueurs ouverts'), findsOneWidget);
    expect(find.text('Tâches terminées'), findsOneWidget);
    expect(find.text('Prêts pour Leasing'), findsOneWidget);
    expect(find.text('Logement 304'), findsOneWidget);
    expect(find.text('Place du Parc'), findsOneWidget);
    expect(find.text('2/3 tâches'), findsOneWidget);
    expect(find.text('Peinture finale et inspection cuisine'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Logement 304'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Logement 304'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Détail du logement 304'), findsOneWidget);
    expect(find.text('Tâches'), findsOneWidget);
    expect(find.text('Sophie Tremblay'), findsOneWidget);
  });

  testWidgets('shows an empty state when the backend has no renovation apartments', (tester) async {
    ApiService.instance.client = buildClient(
      commandCenter: {
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
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('Aucun logement de rénovation pour le moment'), findsOneWidget);
    expect(find.text('Rafraîchir'), findsOneWidget);
  });

  testWidgets('shows an error state when the dashboard request fails', (tester) async {
    ApiService.instance.client = MockClient((request) async {
      return http.Response(
        jsonEncode({'message': 'boom'}),
        500,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Impossible de charger le tableau de bord de rénovation'), findsOneWidget);
    expect(find.textContaining('boom'), findsWidgets);
  });
}
