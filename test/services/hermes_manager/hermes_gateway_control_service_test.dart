import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesGatewayControlService', () {
    test('constructs without arguments', () {
      expect(
        HermesGatewayControlService.new,
        returnsNormally,
      );
    });

    test('constructs with settings preference service', () {
      expect(
        () => HermesGatewayControlService(null),
        returnsNormally,
      );
    });

    test('isRunning returns false initially', () {
      final service = HermesGatewayControlService();
      expect(service.isRunning, isFalse);
    });

    test('getStatus returns service info', () {
      final service = HermesGatewayControlService();
      final status = service.getStatus();
      expect(status['service'], 'hermes-gateway');
      expect(status['running'], isFalse);
      expect(status.containsKey('pid'), isTrue);
    });

    test('stop returns immediately when not running', () async {
      final service = HermesGatewayControlService();
      final stopped = await service.stop();
      expect(stopped, isTrue);
      expect(service.isRunning, isFalse);
    });
  });
}
