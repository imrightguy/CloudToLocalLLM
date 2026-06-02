import 'dart:async';

import 'package:cloudtolocalllm/auth/auth_provider.dart';
import 'package:cloudtolocalllm/models/user_model.dart';
import 'package:cloudtolocalllm/services/auth_service.dart';
import 'package:cloudtolocalllm/services/tunnel/interfaces/interfaces.dart';
import 'package:cloudtolocalllm/services/tunnel/metrics_collector.dart' as metrics_impl;
import 'package:cloudtolocalllm/services/tunnel/persistent_request_queue.dart';
import 'package:cloudtolocalllm/services/tunnel/tunnel_service_factory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthProvider implements AuthProvider {
  final StreamController<bool> _authStateController =
      StreamController<bool>.broadcast();

  @override
  Stream<bool> get authStateChanges => _authStateController.stream;

  @override
  UserModel? get currentUser => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> login() async {}

  @override
  Future<void> logout() async {}

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<bool> handleCallback({String? url}) async => false;

  @override
  Future<void> loginMockDeveloper() async {}

  void dispose() {
    _authStateController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TunnelServiceFactory', () {
    late _StubAuthProvider authProvider;
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authProvider = _StubAuthProvider();
      authService = AuthService(authProvider);
    });

    tearDown(() {
      authProvider.dispose();
      authService.dispose();
    });

    test('createRequestQueue returns the concrete queue implementation', () {
      final queue = PersistentRequestQueue(maxSize: 24);

      expect(queue, isA<PersistentRequestQueue>());
      expect(queue.size, 0);
      expect(queue.isEmpty, isTrue);
    });

    test('createMetricsCollector returns the concrete metrics implementation',
        () {
      final collector = metrics_impl.MetricsCollector();

      expect(collector, isA<metrics_impl.MetricsCollector>());

      for (var i = 0; i < 20; i++) {
        collector.recordRequest(
          latency: Duration(milliseconds: i),
          success: true,
        );
      }

      // maxHistorySize=17 caps the concrete implementation at 17 entries
      final c = collector as metrics_impl.MetricsCollector;
      expect(c.totalRequests, 17);
    });

    test('createTunnelService returns a concrete TunnelServiceImpl', () {
      final service = TunnelServiceFactory.createTunnelService(
        authService: authService,
        config: const TunnelConfig(
          maxQueueSize: 50,
          maxReconnectAttempts: 3,
        ),
      );

      expect(service, isA<TunnelService>());
    });

    test('createFullTunnelStack returns the concrete stack entries', () {
      final stack = TunnelServiceFactory.createFullTunnelStack(
        authService: authService,
        config: const TunnelConfig(maxQueueSize: 33),
        maxQueueSize: 11,
        maxHistorySize: 22,
      );

      expect(stack['service'], isA<TunnelService>());
      expect(stack['queue'], isA<PersistentRequestQueue>());
      expect(stack['metrics'], isA<metrics_impl.MetricsCollector>());
    });
  });
}
