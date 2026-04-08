import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:immogestion/models.dart';
import 'package:immogestion/services/activity_service.dart';

/// Live integration tests against the running backend.
///
/// Requires: `node src/server.js` running on localhost:3000
/// Run: `flutter test test/integration_test.dart`
void main() {
  late String token;

  setUpAll(() async {
    // Direct HTTP calls to live backend — no ApiService wrapper needed in tests.
  });

  group('Auth flow', () {
    test('login returns tokens and user', () async {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'admin@immogestion.com',
          'password': 'Test1234!',
        }),
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);

      final data = body['data'] as Map<String, dynamic>;
      expect(data['tokens'], isNotNull);
      expect(data['tokens']['accessToken'], isA<String>());
      expect(data['tokens']['refreshToken'], isA<String>());
      expect(data['user'], isNotNull);
      expect(data['user']['email'], 'admin@immogestion.com');

      token = data['tokens']['accessToken'] as String;
    });

    test('get profile with token', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/auth/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data']['email'], 'admin@immogestion.com');
    });
  });

  group('Buildings', () {
    test('GET /buildings returns paginated list', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/buildings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data'], isA<List>());
      expect(body['metadata'], isNotNull);
      expect(body['metadata']['total'], greaterThan(0));

      // Parse first building into model
      final buildings = body['data'] as List;
      final building = BuildingItem.fromJson(buildings[0] as Map<String, dynamic>);
      expect(building.id, isNotNull);
      expect(building.name, isNotEmpty);
      expect(building.address, isNotEmpty);
      expect(building.totalUnits, greaterThan(0));
    });

    test('GET /buildings/:id returns single building', () async {
      // First get a building ID
      final listResp = await http.get(
        Uri.parse('http://localhost:3000/api/buildings'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final list = jsonDecode(listResp.body)['data'] as List;
      final id = list[0]['id'] as String;

      final response = await http.get(
        Uri.parse('http://localhost:3000/api/buildings/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final building = BuildingItem.fromJson(body['data'] as Map<String, dynamic>);
      expect(building.id, id);
    });
  });

  group('Leads', () {
    test('GET /leads returns paginated list with snake_case stages', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/leads'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data'], isA<List>());

      final leads = body['data'] as List;
      if (leads.isNotEmpty) {
        final lead = LeadItem.fromJson(leads[0] as Map<String, dynamic>);
        expect(lead.id, isNotNull);
        expect(lead.fullName, isNotEmpty);
        expect(lead.email, isNotEmpty);
        // Stage should parse from snake_case (e.g. visite_planifiee → visitePlanifiee)
        expect(lead.stage, isA<LeadStage>());
        // budgetCents should be read correctly
        expect(lead.budget, isA<int>());
      }
    });

    test('POST /leads creates a lead', () async {
      final response = await http.post(
        Uri.parse('http://localhost:3000/api/leads'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fullName': 'Intégration Test',
          'email': 'integration@test.com',
          'phone': '514-555-9999',
          'source': 'web',
          'stage': 'nouveau',
          'language': 'fr',
        }),
      );

      expect(response.statusCode, inInclusiveRange(200, 201));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data']['fullName'], 'Intégration Test');
      expect(body['data']['email'], 'integration@test.com');
    });
  });

  group('Visits', () {
    test('GET /visits returns list with nested relations', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/visits'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data'], isA<List>());

      final visits = body['data'] as List;
      if (visits.isNotEmpty) {
        // Visit model should extract from nested objects
        final visit = VisitItem.fromJson(visits[0] as Map<String, dynamic>);
        expect(visit.id, isNotNull);
        expect(visit.status, isNotEmpty);
        // Nested fields should be extracted
        expect(visit.unitLabel, isNotNull);
        expect(visit.buildingName, isNotNull);
        expect(visit.agent, isNotNull);
      }
    });
  });

  group('Analytics', () {
    test('GET /analytics/dashboard returns full dashboard data', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/analytics/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);

      final data = body['data'] as Map<String, dynamic>;
      expect(data['pipeline'], isA<Map>());
      expect(data['weeklyStats'], isA<Map>());
      expect(data['visitStats'], isA<Map>());
      expect(data['conversionRates'], isA<Map>());
      expect(data['leadSources'], isA<List>());
    });
  });

  group('Activity', () {
    test('GET /communications/activity returns activity feed', () async {
      final response = await http.get(
        Uri.parse('http://localhost:3000/api/communications/activity'),
        headers: {'Authorization': 'Bearer $token'},
      );

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body['success'], isTrue);
      expect(body['data'], isA<List>());

      final activities = body['data'] as List;
      if (activities.isNotEmpty) {
        final event = ActivityEvent.fromJson(activities[0] as Map<String, dynamic>);
        expect(event.type, isNotEmpty);
        expect(event.timestamp, isNotNull);
        // description should map to title
        expect(event.title, isNotEmpty);
      }
    });
  });
}
