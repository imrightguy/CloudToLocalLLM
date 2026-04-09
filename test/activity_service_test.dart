import 'package:flutter_test/flutter_test.dart';
import 'package:immogestion/services/activity_service.dart';

void main() {
  group('ActivityEvent', () {
    test('fromJson parses all fields', () {
      final event = ActivityEvent.fromJson({
        'id': 'a1',
        'type': 'lead_created',
        'title': 'Nouveau lead',
        'detail': 'Émilie Beaudoin a soumis une demande',
        'timestamp': '2024-06-15T10:30:00.000Z',
        'relatedId': 'l1',
        'relatedType': 'lead',
      });

      expect(event.id, 'a1');
      expect(event.type, 'lead_created');
      expect(event.title, 'Nouveau lead');
      expect(event.detail, 'Émilie Beaudoin a soumis une demande');
      expect(event.timestamp, DateTime.utc(2024, 6, 15, 10, 30));
      expect(event.relatedId, 'l1');
      expect(event.relatedType, 'lead');
    });

    test('fromJson infers relatedType from type field', () {
      final leadEvent = ActivityEvent.fromJson({
        'type': 'lead_stage_changed',
        'title': 'Lead avancé',
        'detail': 'test',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(leadEvent.relatedType, 'lead');

      final visitEvent = ActivityEvent.fromJson({
        'type': 'visit_scheduled',
        'title': 'Visite planifiée',
        'detail': 'test',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(visitEvent.relatedType, 'visit');

      final genericEvent = ActivityEvent.fromJson({
        'type': 'system_update',
        'title': 'System',
        'detail': 'test',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(genericEvent.relatedType, isNull);
    });

    test('fromJson defaults missing fields', () {
      final event = ActivityEvent.fromJson({});
      expect(event.id, isNull);
      expect(event.type, 'info');
      expect(event.title, '');
      expect(event.detail, '');
      expect(event.relatedId, isNull);
      expect(event.relatedType, isNull);
    });

    test('fromJson uses DateTime.now() when timestamp is null', () {
      final before = DateTime.now();
      final event = ActivityEvent.fromJson({});
      final after = DateTime.now();
      expect(event.timestamp.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(event.timestamp.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('fromJson uses description as fallback for title and detail', () {
      final event = ActivityEvent.fromJson({
        'description': 'Fallback text',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(event.title, 'Fallback text');
      expect(event.detail, 'Fallback text');
    });

    test('fromJson prefers title/detail over description', () {
      final event = ActivityEvent.fromJson({
        'title': 'Specific title',
        'detail': 'Specific detail',
        'description': 'Fallback',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(event.title, 'Specific title');
      expect(event.detail, 'Specific detail');
    });

    test('fromJson uses leadId as fallback for relatedId', () {
      final event = ActivityEvent.fromJson({
        'leadId': 'l42',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(event.relatedId, 'l42');
    });

    test('fromJson prefers relatedId over leadId', () {
      final event = ActivityEvent.fromJson({
        'relatedId': 'r1',
        'leadId': 'l42',
        'timestamp': '2024-06-15T10:00:00.000Z',
      });
      expect(event.relatedId, 'r1');
    });

    test('toJson round-trips', () {
      final original = ActivityEvent(
        id: 'a1',
        type: 'visit_completed',
        title: 'Visite terminée',
        detail: 'Visite avec Émilie',
        timestamp: DateTime(2024, 6, 15, 14, 0),
        relatedId: 'v1',
        relatedType: 'visit',
      );
      final json = original.toJson();
      expect(json['id'], 'a1');
      expect(json['type'], 'visit_completed');
      expect(json['relatedId'], 'v1');
      expect(json['relatedType'], 'visit');

      final restored = ActivityEvent.fromJson(json);
      expect(restored.title, original.title);
      expect(restored.detail, original.detail);
      expect(restored.relatedType, original.relatedType);
    });

    test('toJson omits null optional fields', () {
      final event = ActivityEvent(
        type: 'info',
        title: 'Test',
        detail: 'test',
        timestamp: DateTime(2024, 1, 1),
      );
      final json = event.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('relatedId'), isFalse);
      expect(json.containsKey('relatedType'), isFalse);
    });
  });
}
