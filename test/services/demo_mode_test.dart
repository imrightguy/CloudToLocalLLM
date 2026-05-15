import 'package:flutter_test/flutter_test.dart';

import 'package:immogestion/services/demo_mode.dart';

void main() {
  test('DemoMode exposes the app config defaults', () {
    expect(DemoMode.isInternalDemoMode, isFalse);
    expect(DemoMode.usesLiveApi, isTrue);
    expect(DemoMode.activeDemoProfile, 'none');
  });
}
