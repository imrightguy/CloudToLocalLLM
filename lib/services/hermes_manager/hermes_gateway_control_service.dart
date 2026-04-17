
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayControlService');

/// Manages the hermes-agent gateway process.
///
/// This service handles starting, stopping, and restarting the hermes-agent
/// gateway, similar to how OpenClaw gateway is managed.
class HermesGatewayControlService {
  static const String _hermesCommand = 'hermes-agent';
  static const String _gatewaySubcommand = 'gateway';

  Process? _gatewayProcess;
  bool _isRunning = false;

  /// Start the hermes-agent gateway.
  ///
  /// Returns true if the gateway started successfully.
  Future<bool> start() async {
    if (_isRunning) {
      _log.info('Hermes gateway is already running');
      return true;
    }

    try {
      _gatewayProcess = await Process.start(
        _hermesCommand,
        [_gatewaySubcommand, 'start', '--json'],
        runInShell: true,
      );

      // Optional: read stdout/stderr to verify startup
      _gatewayProcess?.stdout.transform(utf8.decoder).listen((data) {
        _log.fine('Hermes gateway stdout: $data');
      });
      _gatewayProcess?.stderr.transform(utf8.decoder).listen((data) {
        _log.warning('Hermes gateway stderr: $data');
      });

      final exitCode = await _gatewayProcess?.exitCode;
      if (exitCode == 0) {
        _isRunning = true;
        _log.info('Hermes gateway started successfully');
        return true;
      } else {
        _log.severe('Hermes gateway exited with code $exitCode');
        return false;
      }
    } catch (e, st) {
      _log.severe('Failed to start Hermes gateway', e, st);
      return false;
    }
  }

  /// Stop the hermes-agent gateway.
  ///
  /// Returns true if the gateway was stopped successfully.
  Future<bool> stop() async {
    if (!_isRunning) {
      _log.info('Hermes gateway is not running');
      return true;
    }

    try {
      // Send interrupt signal
      _gatewayProcess?.kill(ProcessSignal.sigint);

      // Wait for process to exit (with timeout)
      await Future.any([
        _gatewayProcess?.exitCode,
        Future.delayed(const Duration(seconds: 5), () {
          _gatewayProcess?.kill(ProcessSignal.sigkill);
        }),
      ]);

      _isRunning = false;
      _log.info('Hermes gateway stopped');
      return true;
    } catch (e, st) {
      _log.severe('Failed to stop Hermes gateway', e, st);
      return false;
    }
  }

  /// Restart the hermes-agent gateway.
  ///
  /// Returns true if the gateway restarted successfully.
  Future<bool> restart() async {
    _log.info('Restarting Hermes gateway');
    await stop();
    return await start();
  }

  /// Check if the hermes-agent gateway is running.
  bool get isRunning => _isRunning;

  /// Get gateway status information.
  Map<String, dynamic> getStatus() {
    return {
      'service': 'hermes-gateway',
      'running': _isRunning,
      'pid': _gatewayProcess?.pid,
    };
  }
}