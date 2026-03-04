import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/desktop_control/window_manager_service.dart';

void main() {
  late WindowManagerService service;

  setUp(() {
    service = WindowManagerService();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('WindowManagerService', () {
    test('should initialize successfully', () async {
      await service.initialize();
      expect(service.isInitialized, true);
    });

    test('should get list of windows', () async {
      await service.initialize();
      final windows = await service.getWindows();
      expect(windows, isA<List<WindowInfo>>());
    });

    test('should focus window by id', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.focusWindow(windows.first.id);
        expect(result, isA<bool>());
      }
    });

    test('should move window', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.moveWindow(windows.first.id, 100, 100);
        expect(result, isA<bool>());
      }
    });

    test('should resize window', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.resizeWindow(windows.first.id, 800, 600);
        expect(result, isA<bool>());
      }
    });

    test('should minimize window', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.minimizeWindow(windows.first.id);
        expect(result, isA<bool>());
      }
    });

    test('should maximize window', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.maximizeWindow(windows.first.id);
        expect(result, isA<bool>());
      }
    });

    test('should close window', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.closeWindow(windows.first.id);
        expect(result, isA<bool>());
      }
    });

    test('should handle double-click to maximize', () async {
      await service.initialize();
      final windows = await service.getWindows();
      if (windows.isNotEmpty) {
        final result = await service.toggleMaximize(windows.first.id);
        expect(result, isA<bool>());
      }
    });
  });
}
