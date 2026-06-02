import 'package:cloudtolocalllm/services/hermes/hermes_process_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesProcessClient', () {
    test('constructs without error', () {
      expect(
        HermesProcessClient.new,
        returnsNormally,
      );
    });

    test('initial connection state is disconnected', () {
      final client = HermesProcessClient();
      expect(client.connection.isActive, isFalse);
      expect(client.connection.state.name, 'disconnected');
    });

    test('initial message stream is broadcast', () {
      final client = HermesProcessClient();
      expect(client.messageStream.isBroadcast, isTrue);
    });

    test('getAvailableModels returns default model', () async {
      final client = HermesProcessClient();
      final models = await client.getAvailableModels();
      expect(models, ['default']);
    });

    test('closeConnection is safe on fresh client', () async {
      final client = HermesProcessClient();
      await client.closeConnection();
      expect(client.connection.isActive, isFalse);
    });

    test('dispose clears connection state', () {
      final client = HermesProcessClient();
      client.dispose();
      expect(client.connection.state.name, 'disconnected');
    });
  });
}
