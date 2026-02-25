import 'dart:async';
import 'dart:io';
import 'package:process_run/shell.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_notifier/local_notifier.dart';
import '../utils/logger.dart';

/// Service for low-level OS control and system monitoring on Linux
class SystemControlService {
  final Shell _shell = Shell();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  bool _isNotifierInitialized = false;

  /// Initialize system control service
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await localNotifier.setup(
        appName: 'CloudToLocalLLM',
      );
      _isNotifierInitialized = true;
      appLogger.info('[SystemControl] Local notifier initialized');
    } catch (e) {
      appLogger.error('[SystemControl] Failed to initialize local notifier',
          error: e);
    }
  }

  /// Show a system notification
  Future<void> showNotification(String title, String body) async {
    if (!_isNotifierInitialized) await initialize();
    if (kIsWeb) return;

    try {
      LocalNotification notification = LocalNotification(
        title: title,
        body: body,
      );
      unawaited(notification.show());
    } catch (e) {
      appLogger.error('[SystemControl] Failed to show notification', error: e);
    }
  }

  /// Execute a shell command
  Future<String?> executeCommand(String command) async {
    try {
      if (kIsWeb) return 'Not supported on web';
      appLogger.info('[SystemControl] Executing command: $command');
      final results = await _shell.run(command);
      return results.map((r) => r.outText).join('\n');
    } catch (e) {
      appLogger.error('[SystemControl] Command execution failed: $command',
          error: e);
      return 'Error: $e';
    }
  }

  /// Get CPU and RAM usage
  Future<Map<String, String>> getSystemStats() async {
    final stats = <String, String>{
      'cpu': 'N/A',
      'ram': 'N/A',
      'uptime': 'N/A',
    };

    if (kIsWeb || !Platform.isLinux) return stats;

    try {
      // Get RAM stats (free -h)
      final ramResult = await _shell.run('free -h');
      if (ramResult.isNotEmpty) {
        // Find the line starting with "Mem:"
        final lines = ramResult.first.outText.split('\n');
        final memLine =
            lines.firstWhere((l) => l.startsWith('Mem:'), orElse: () => '');
        if (memLine.isNotEmpty) {
          stats['ram'] = memLine.trim();
        }
      }

      // Get CPU stats (basic load average via uptime)
      final uptimeResult = await _shell.run('uptime');
      if (uptimeResult.isNotEmpty) {
        final out = uptimeResult.first.outText.trim();
        stats['uptime'] = out;
        // Extract load average if possible
        if (out.contains('load average:')) {
          stats['cpu'] = out.split('load average:').last.trim();
        }
      }
    } catch (e) {
      appLogger.error('[SystemControl] Failed to get system stats', error: e);
    }

    return stats;
  }

  /// Capture full desktop screenshot
  Future<String?> captureScreenshot() async {
    if (kIsWeb || !Platform.isLinux) return null;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '/tmp/cloudtolocalllm_screenshot_$timestamp.png';

    try {
      // Try gnome-screenshot first, then scrot
      try {
        await _shell.run('gnome-screenshot -f $path');
      } catch (_) {
        try {
          await _shell.run('scrot $path');
        } catch (_) {
          appLogger.error(
              '[SystemControl] Neither gnome-screenshot nor scrot found');
          return null;
        }
      }

      if (File(path).existsSync()) {
        appLogger.info('[SystemControl] Screenshot saved to $path');
        await showNotification('Screenshot Captured', 'Saved to $path');
        return path;
      }
    } catch (e) {
      appLogger.error('[SystemControl] Screenshot failed', error: e);
    }

    return null;
  }

  /// Get Linux hardware info
  Future<LinuxDeviceInfo?> getLinuxDeviceInfo() async {
    if (kIsWeb || !Platform.isLinux) return null;
    try {
      return await _deviceInfo.linuxInfo;
    } catch (e) {
      appLogger.error('[SystemControl] Failed to get device info', error: e);
      return null;
    }
  }

  /// Control system volume
  Future<void> adjustVolume(bool increase) async {
    if (kIsWeb || !Platform.isLinux) return;
    final cmd = increase ? 'amixer set Master 5%+' : 'amixer set Master 5%-';
    await executeCommand(cmd);
  }

  /// Toggle system mute
  Future<void> toggleMute() async {
    if (kIsWeb || !Platform.isLinux) return;
    await executeCommand('amixer set Master toggle');
  }
}
