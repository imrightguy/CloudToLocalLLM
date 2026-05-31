import 'package:cloudtolocalllm/services/popout/popout_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PopOutManager tracks branch-specific windows independently', () {
    final manager = PopOutManager();

    manager.togglePopOut('agents', 0);
    manager.togglePopOut('agents', 1);

    final snapshot = manager.toJson();
    final openWindows = snapshot['openWindows'] as Map<String, dynamic>;

    expect(openWindows.length, 2);
    expect(openWindows.containsKey('agents:0'), isTrue);
    expect(openWindows.containsKey('agents:1'), isTrue);
    expect(openWindows['agents:0']['branchIndex'], 0);
    expect(openWindows['agents:1']['branchIndex'], 1);
  });

  test('PopOutManager closes only the requested branch window', () {
    final manager = PopOutManager();

    manager.togglePopOut('agents', 0);
    manager.togglePopOut('agents', 1);
    manager.togglePopOut('agents', 0);

    final snapshot = manager.toJson();
    final openWindows = snapshot['openWindows'] as Map<String, dynamic>;

    expect(openWindows.length, 1);
    expect(openWindows.containsKey('agents:0'), isFalse);
    expect(openWindows.containsKey('agents:1'), isTrue);
    expect(openWindows['agents:1']['branchIndex'], 1);
  });
}
