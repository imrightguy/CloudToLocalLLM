import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../di/locator.dart';

/// Data returned by [AppBootstrapper] after the core environment is ready.
class AppBootstrapData {
  AppBootstrapData({required this.isWeb, required this.supportsNativeShell});

  final bool isWeb;
  final bool supportsNativeShell;
}

/// Handles the one-time initialization that must occur before the widget tree
/// is built.  This ensures heavy setup only happens once at application start.
class AppBootstrapper {
  AppBootstrapper();

  Future<Process>? _sttProcess;

  Future<AppBootstrapData> load() async {
    try {
      debugPrint('[Bootstrapper] Starting bootstrap process...');

      // Start local STT server (faster-whisper) on Windows
      if (!kIsWeb && Platform.isWindows) {
        _startSttServer();
      }

      debugPrint('[Bootstrapper] Setting up service locator...');
      await setupServiceLocator().timeout(
        const Duration(seconds: 25),
        onTimeout: () {
          debugPrint(
              '[Bootstrapper] Service locator setup timed out after 25s; continuing with degraded startup');
        },
      );
      debugPrint('[Bootstrapper] Service locator setup completed');

      debugPrint('[Bootstrapper] Bootstrap completed successfully');
      return AppBootstrapData(isWeb: kIsWeb, supportsNativeShell: !kIsWeb);
    } catch (e, stack) {
      debugPrint('[Bootstrapper] ERROR during bootstrap: $e');
      debugPrint('[Bootstrapper] Stack trace: $stack');
      rethrow;
    }
  }

  void _startSttServer() {
    try {
      final scriptPath = _findSttScript();
      if (scriptPath == null) {
        debugPrint('[Bootstrapper] STT script not found, skipping');
        return;
      }

      // Add CUDA DLL path so faster-whisper can find cublas
      const cudaPath = r'C:\Users\rightguy\AppData\Local\Programs\Ollama\lib\ollama\cuda_v12';
      final env = Map<String, String>.from(Platform.environment);
      final path = env['PATH'] ?? '';
      if (!path.contains(cudaPath)) {
        env['PATH'] = '$cudaPath;$path';
      }

      _sttProcess = Process.start(
        'python',
        [scriptPath],
        environment: env,
        runInShell: true,
      ).then((process) {
        debugPrint('[Bootstrapper] STT server started (PID: ${process.pid})');
        process.stderr.transform(utf8.decoder).listen((line) {
          debugPrint('[STT] $line');
        });
        process.exitCode.then((code) {
          debugPrint('[Bootstrapper] STT server exited with code $code');
        });
        return process;
      }).catchError((e) {
        debugPrint('[Bootstrapper] Failed to start STT server: $e');
        return null;
      });
    } catch (e) {
      debugPrint('[Bootstrapper] Error starting STT server: $e');
    }
  }

  String? _findSttScript() {
    const candidates = [
      r'C:\Users\rightguy\Documents\CloudToLocalLLM\scripts\stt_server.py',
      'stt_server.py',
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }
    return null;
  }

  void dispose() {
    _sttProcess?.then((p) => p?.kill());
    _sttProcess = null;
  }
}
