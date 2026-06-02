import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayControlService');

/// Manages the hermes-agent gateway process.
///
/// This service handles starting, stopping, and restarting the hermes-agent
/// gateway, similar to how OpenClaw gateway is managed.
///
/// NOTE: The gateway is a long-running daemon. We do NOT await its exit code
/// after start — that would hang forever. Instead we watch for a brief health
/// signal on stdout/stderr to confirm it launched.
class HermesGatewayControlService {
  static const String _hermesCommand = 'hermes-agent';
  static const String _gatewaySubcommand = 'gateway';

  Process? _gatewayProcess;
  bool _isRunning = false;

  HermesGatewayControlService([Object? settingsPreferenceService]);

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
        [_gatewaySubcommand, 'start'],
        runInShell: true,
        // Don't inherit stdin — gateway runs as daemon
      );

      // Read stdout/stderr asynchronously (don't await exitCode — daemon never exits)
      late final StreamSubscription<String> stdoutSub;
      late final StreamSubscription<String> stderrSub;
      stdoutSub = _gatewayProcess!.stdout.transform(utf8.decoder).listen((data) {
        _log.fine('Hermes gateway stdout: $data');
        // Check for startup confirmation
        if (data.toLowerCase().contains('started') || data.toLowerCase().contains('running')) {
          _isRunning = true;
          _log.info('Hermes gateway started successfully');
        }
      });
      stderrSub = _gatewayProcess!.stderr.transform(utf8.decoder).listen((data) {
        _log.warning('Hermes gateway stderr: $data');
      });

      // Give the process a moment to emit startup output; if it dies
      // immediately we'll catch that on the exit code stream.
      unawaited(_gatewayProcess!.exitCode.then((code) {
        _log.warning('Hermes gateway exited with code $code');
        _isRunning = false;
        stdoutSub.cancel();
        stderrSub.cancel();
      }));

      // Brief wait for startup signal, then assume success
      await Future.delayed(const Duration(seconds: 2));
      // If process died within 2 seconds, _isRunning is false
      if (!_isRunning && _gatewayProcess != null) {
        // Check if process is still alive
        try {
          final pid = _gatewayProcess!.pid;
          _log.info('Hermes gateway process running (pid: $pid)');
          _isRunning = true;
        } catch (_) {
          _log.severe('Hermes gateway process died during startup');
          return false;
        }
      }

      return _isRunning;
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
      await Future.any<int?>([
        _gatewayProcess?.exitCode ?? Future<int?>.value(null),
        Future<int?>.delayed(const Duration(seconds: 5), () {
          _gatewayProcess?.kill(ProcessSignal.sigkill);
          return null;
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
