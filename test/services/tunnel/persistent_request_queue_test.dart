import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';
import 'package:cloudtolocalllm/services/tunnel/persistent_request_queue.dart';

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

  test('restorePersistedRequests preserves overflow and skips malformed data',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = buildQueuedRequest(
      id: 'req-1',
      userId: 'user-1',
      enqueuedAt: DateTime.parse('2026-05-10T12:00:00.000Z'),
    );
    final second = buildQueuedRequest(
      id: 'req-2',
      userId: 'user-2',
      enqueuedAt: DateTime.parse('2026-05-10T12:01:00.000Z'),
    );

    await prefs.setStringList('tunnel_queued_requests', <String>[
      jsonEncode(first.toJson()),
      '{not valid json}',
      jsonEncode(second.toJson()),
    ]);

    final queue = PersistentRequestQueue(maxSize: 1);
    final restored = await queue.restorePersistedRequests();

    expect(restored, 1);
    expect(queue.size, 1);
    expect(queue.peek()?.id, 'req-1');

    final remaining = prefs.getStringList('tunnel_queued_requests');
    expect(remaining, isNotNull);
    expect(remaining, hasLength(1));

    final retained = jsonDecode(remaining!.single) as Map<String, dynamic>;
    expect((retained['request'] as Map<String, dynamic>)['id'], 'req-2');
  });
}
