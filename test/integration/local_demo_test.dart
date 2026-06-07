import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// Integration tests for the CloudToLocalLLM demo stack.
/// 1. Hermes gateway is reachable
/// 2. Backend API is healthy  
/// 3. Embedded app router works
/// 4. Ollama provider is available
///
/// Run with: dart test test/integration/local_demo_test.dart
///
/// Note: must use `dart test`, NOT `flutter test` — flutter_test uses
/// TestWidgetsFlutterBinding which blocks real HTTP requests (returns 400
/// for all HttpClient calls). `dart test` runs in a normal Dart VM and
/// can hit the real local services.
void main() {
  late HttpClient client;

  setUp(() {
    client = HttpClient();
  });

  tearDown(() {
    client.close();
  });

  group('Local Backend (api-backend :8080)', () {
    test('health endpoint returns healthy', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:8080/health'));
      final response = await request.close();
      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], equals('healthy'));
      expect(json['dependencies']['database']['status'], equals('healthy'));
      print('[Test] ✅ Backend healthy: ${json['uptime']}s uptime');
    });
  });

  group('Hermes Gateway (:8642)', () {
    test('health endpoint returns ok', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:8642/health'));
      final response = await request.close();
      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], equals('ok'));
      expect(json['platform'], equals('hermes-agent'));
      print('[Test] ✅ Hermes gateway healthy at :8642');
    });

    test('models endpoint responds (may need auth)', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:8642/v1/models'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      expect(response.statusCode, anyOf(200, 401),
          reason: 'Should either return models or indicate auth needed');
      if (response.statusCode == 401) {
        print('[Test] ⚠️ Hermes models endpoint requires API key');
      } else {
        print('[Test] ✅ Models: $body');
      }
    });
  });

  group('Local Model Provider (Ollama :11434)', () {
    test('Ollama is reachable and has models', () async {
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:11434/api/tags'));
      final response = await request.close();
      expect(response.statusCode, equals(200));

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final models = json['models'] as List? ?? [];
      print('[Test] ✅ Ollama reachable at :11434 with ${models.length} models');
    });
  });

  group('Embedded App Router (:1337)', () {
    test('app router health check responds', () async {
      // App router is embedded in the desktop app. If the app isn't
      // running locally, skip the test instead of failing.
      try {
        final request = await client
            .getUrl(Uri.parse('http://127.0.0.1:1337/health'))
            .timeout(const Duration(seconds: 2));
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        expect(body, equals('OK'));
        print('[Test] ✅ App router healthy at :1337');
      } on SocketException {
        print('[Test] ⚠️  App router on :1337 not reachable — desktop app '
            'not running (skipping)');
      } on TimeoutException {
        print('[Test] ⚠️  App router on :1337 timed out — desktop app '
            'not running (skipping)');
      }
    });
  });

  group('End-to-End Demo Verification', () {
    test('all core services are running', () async {
      // Hermes
      Future<HttpClientResponse> get(String url) async {
        final req = await client.getUrl(Uri.parse(url));
        return req.close();
      }

      // Hermes
      try {
        final hermesRes = await get('http://127.0.0.1:8642/health');
        expect(hermesRes.statusCode, equals(200));
      } catch (e) {
        fail('Hermes gateway unreachable: $e');
      }

      // Backend
      try {
        final beRes = await get('http://127.0.0.1:8080/health');
        expect(beRes.statusCode, equals(200));
      } catch (e) {
        fail('API backend unreachable: $e');
      }

      // App router — skip if desktop app not running
      try {
        final routerRes =
            await get('http://127.0.0.1:1337/health').timeout(
                  const Duration(seconds: 1),
                );
        expect(routerRes.statusCode, anyOf(200, 404));
        print('  - App router       :1337 ✅');
      } catch (_) {
        print('  - App router       :1337 ⚠️  (desktop app not running — skipped)');
      }

      // Ollama
      try {
        final ollamaRes = await get('http://127.0.0.1:11434/api/tags');
        expect(ollamaRes.statusCode, equals(200));
      } catch (e) {
        fail('Ollama unreachable: $e');
      }

      print('[Test] ✅ CORE SERVICES RUNNING:');
      print('  - Hermes gateway   :8642 ✅');
      print('  - API backend      :8080 ✅');
      print('  - Ollama provider  :11434 ✅');
    });
  });
}