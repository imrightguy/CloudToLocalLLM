import 'dart:convert';

import 'package:cloudtolocalllm/services/tunnel/interfaces/tunnel_config.dart';
import 'package:cloudtolocalllm/services/tunnel/tunnel_config_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TunnelConfigManager', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initialize clears malformed tunnel config payloads', () async {
      SharedPreferences.setMockInitialValues({
        'tunnel_config': 'not-json',
        'tunnel_profile': 'stable',
      });

      final manager = TunnelConfigManager();
      await manager.initialize();

      expect(manager.getCurrentConfig(), const TunnelConfig());
      expect(manager.getCurrentProfile(), ProfileType.custom);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('tunnel_config'), isNull);
    });

    test('initialize loads a valid tunnel config payload', () async {
      SharedPreferences.setMockInitialValues({
        'tunnel_config': jsonEncode(
          const TunnelConfig(
            maxReconnectAttempts: 7,
            reconnectBaseDelay: Duration(seconds: 4),
            requestTimeout: Duration(seconds: 45),
            maxQueueSize: 25,
            enableCompression: false,
            enableAutoReconnect: true,
            logLevel: LogLevel.debug,
          ).toJson(),
        ),
        'tunnel_profile': 'stable',
      });

      final manager = TunnelConfigManager();
      await manager.initialize();

      expect(manager.getCurrentConfig().maxReconnectAttempts, 7);
      expect(manager.getCurrentConfig().reconnectBaseDelay, const Duration(seconds: 4));
      expect(manager.getCurrentConfig().requestTimeout, const Duration(seconds: 45));
      expect(manager.getCurrentConfig().maxQueueSize, 25);
      expect(manager.getCurrentConfig().enableCompression, isFalse);
      expect(manager.getCurrentConfig().enableAutoReconnect, isTrue);
      expect(manager.getCurrentConfig().logLevel, LogLevel.debug);
      expect(manager.getCurrentProfile(), ProfileType.stable);
    });
  });
}
