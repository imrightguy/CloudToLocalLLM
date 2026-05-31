import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('paired-device transport remains enabled', () {
    expect(AppConfig.skipDeviceIdentity, isFalse);
  });
}
