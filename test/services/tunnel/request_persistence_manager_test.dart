import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';
import 'package:cloudtolocalllm/services/tunnel/persistent_request_queue.dart';
import 'package:cloudtolocalllm/services/tunnel/request_persistence_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  QueuedRequest buildQueuedRequest({
    required String id,
    required String userId,
    required DateTime enqueuedAt,
  }) {
    return QueuedRequest(
      request: TunnelRequest(
        id: id,
        userId: userId,
        payload: Uint8List.fromList(<int>[1, 2, 3]),
        createdAt: enqueuedAt,
      ),
      priority: RequestPriority.high,
      enqueuedAt: enqueuedAt,
    );
  }

  test('repairCorrupted removes malformed entries and keeps valid requests',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final valid = buildQueuedRequest(
      id: 'req-valid',
      userId: 'user-valid',
      enqueuedAt: DateTime.parse('2026-05-10T12:00:00.000Z'),
    );

    await prefs.setString(
      'tunnel_queued_requests',
      jsonEncode(<Object?>[
        valid.toJson(),
        <String, Object?>{'request': 'not-a-map'},
        'also-not-a-map',
      ]),
    );

    final manager = RequestPersistenceManager();
    final repaired = await manager.repairCorrupted();

    expect(repaired, isTrue);

    final repairedJson = prefs.getString('tunnel_queued_requests');
    expect(repairedJson, isNotNull);

    final decoded = jsonDecode(repairedJson!) as List<dynamic>;
    expect(decoded, hasLength(1));
    expect((decoded.single as Map<String, dynamic>)['request'], isA<Map>());
    expect(
      ((decoded.single as Map<String, dynamic>)['request'] as Map<String, dynamic>)['id'],
      'req-valid',
    );
  });

  test('restorePersistedRequests returns only valid requests', () async {
    final prefs = await SharedPreferences.getInstance();
    final valid = buildQueuedRequest(
      id: 'req-valid',
      userId: 'user-valid',
      enqueuedAt: DateTime.parse('2026-05-10T12:00:00.000Z'),
    );

    await prefs.setString(
      'tunnel_queued_requests',
      jsonEncode(<Object?>[
        valid.toJson(),
        <String, Object?>{'request': 'not-a-map'},
      ]),
    );

    final manager = RequestPersistenceManager();
    final restored = await manager.restorePersistedRequests(
      clearAfterRestore: false,
    );

    expect(restored, hasLength(1));
    expect(restored.single.request.id, 'req-valid');

    final stored = prefs.getString('tunnel_queued_requests');
    expect(stored, isNotNull);
    final decoded = jsonDecode(stored!) as List<dynamic>;
    expect(decoded, hasLength(2));
  });
}
