import 'package:cloudtolocalllm/services/hermes_manager/hermes_gateway_control_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesGatewayControlService', () {
    test('constructs without settings service', () {
      expect(
        () => HermesGatewayControlService(),
        returnsNormally,
      );
    });

    test('constructs with settings service', () {
      expect(
        () => HermesGatewayControlService('test'),
        returnsNormally,
      );
    });
  });
}
