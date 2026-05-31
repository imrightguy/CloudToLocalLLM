import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloudtolocalllm/services/tunnel/connection_state_tracker.dart';
import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_models.dart';
import 'package:cloudtolocalllm/services/tunnel/ssh_host_key_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('ConnectionStateTracker filters malformed event history entries', () {
    final tracker = ConnectionStateTracker();

    tracker.fromJson(<String, dynamic>{
      'id': 'conn-1',
      'userId': 'user-1',
      'serverUrl': 'https://example.invalid',
      'connectedAt': '2026-05-10T12:00:00.000Z',
      'lastActivityAt': '2026-05-10T12:00:01.000Z',
      'state': 'connected',
      'reconnectAttempts': 2,
      'eventHistory': <Object?>[
        <String, Object?>{
          'timestamp': '2026-05-10T12:00:00.000Z',
          'type': 'connected',
          'message': 'ok',
        },
      ],
    });

    expect(tracker.connection, isNotNull);
    expect(tracker.connection?.id, 'conn-1');
    expect(tracker.state, TunnelConnectionState.connected);
    expect(tracker.connection?.eventHistory, hasLength(1));

    tracker.fromJson(<String, dynamic>{
      'id': 'conn-bad',
      'userId': 'user-bad',
      'serverUrl': 'https://example.invalid',
      'connectedAt': '2026-05-10T12:00:00.000Z',
      'lastActivityAt': '2026-05-10T12:00:01.000Z',
      'state': 'connected',
      'reconnectAttempts': 2,
      'eventHistory': <Object?>[
        <String, Object?>{
          'timestamp': 'not-a-timestamp',
          'type': 'connected',
          'message': 'bad',
        },
      ],
    });

    expect(tracker.connection?.id, 'conn-bad');
    expect(tracker.state, TunnelConnectionState.connected);
    expect(tracker.connection?.eventHistory, isEmpty);
  });

  test('SSHHostKeyManager removes malformed host key cache and keeps valid keys',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ssh_host_keys', '{not valid json}');

    final manager = SSHHostKeyManager(prefs: prefs);

    final result = await manager.verifyHostKey(
      host: 'example.invalid',
      key: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIexample',
    );

    expect(result.verified, isTrue);
    expect(result.isNewKey, isTrue);
    expect(manager.getTrustedKeys(), containsPair('example.invalid', 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIexample'));
    expect(prefs.getString('ssh_host_keys'), isNotNull);
  });
}
