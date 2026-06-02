import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../models/agent_event.dart';
import '../../models/streaming_message.dart';
import '../streaming_service.dart';

/// Process-based Hermes Agent client.
///
/// Spawns `hermes-agent` as a child process and communicates via stdin/stdout
/// using `hermes chat -q <prompt>` for each request. This bypasses the HTTP
/// gateway entirely — the connection survives gateway restarts because each
/// request is an independent process that talks to the agent directly.
///
/// This mirrors the Hermes TUI's architecture which uses JSON-RPC over
/// stdin/stdout (via `tui_gateway.entry`). For simplicity, the desktop app
/// uses `hermes chat -q` which is equally resilient and easier to manage.
///
/// Auto-restart: if the process exits with a non-zero code before completing
/// the response, the client retries once transparently.
class HermesProcessClient extends StreamingService {
  /// Path to the hermes-agent binary (resolved at first use).
  String? _agentPath;

  /// Process handle for the current streaming request.
  Process? _activeProcess;

  /// Stream controller for message bus (required by abstract interface).
  final StreamController<StreamingMessage> _messageController =
      StreamController<StreamingMessage>.broadcast();

  /// Stream controller for agent events.
  /// Consumers who want structured tool/run lifecycle events listen here.
  final StreamController<AgentEvent> _agentEventController =
      StreamController<AgentEvent>.broadcast();

  /// Cached connection state.
  StreamingConnection _connection = StreamingConnection.disconnected();

  /// Whether this client has been disposed.
  bool _disposed = false;

  /// Max auto-restart attempts per stream call.
  int _restartAttempts = 0;

  /// Stream of structured agent events for consumers who want
  /// tool call and run lifecycle awareness.
  Stream<AgentEvent> get agentEventStream => _agentEventController.stream;

  @override
  Stream<StreamingMessage> get messageStream => _messageController.stream;

  @override
  StreamingConnection get connection => _connection;

  /// Find the `hermes-agent` binary on PATH.
  Future<String> _resolveAgentPath() async {
    if (_agentPath != null) return _agentPath!;

    // Try common locations
    final candidates = [
      'hermes-agent',              // On PATH
    ];

    // Check platform-specific common install locations
    if (Platform.isLinux) {
      candidates.addAll([
        '/home/rightguy/.hermes/hermes-agent/venv/bin/hermes-agent',
        '/usr/local/bin/hermes-agent',
        '/usr/bin/hermes-agent',
      ]);
    } else if (Platform.isMacOS) {
      candidates.addAll([
        '/usr/local/bin/hermes-agent',
        '/opt/homebrew/bin/hermes-agent',
      ]);
    }

    for (final candidate in candidates) {
      try {
        final result = await Process.run(
          candidate,
          ['--version'],
          runInShell: true,
        );
        if (result.exitCode == 0) {
          _agentPath = candidate;
          return candidate;
        }
      } catch (_) {
        // Try next candidate
        continue;
      }
    }

    throw ProcessException('hermes-agent', ['--version'],
        'Not found on PATH or common install locations');
  }

  @override
  Future<void> establishConnection() async {
    if (_disposed) return;

    try {
      await _resolveAgentPath();
      _connection = StreamingConnection.connected('process:hermes-agent');
      debugPrint('[HermesProcess] Agent binary resolved at $_agentPath');
      notifyListeners();
    } on ProcessException catch (e) {
      _connection = StreamingConnection.error(
        'Cannot find hermes-agent: $e',
        endpoint: 'process:hermes-agent',
      );
      notifyListeners();
    } catch (e) {
      _connection = StreamingConnection.error(
        'Connection failed: $e',
        endpoint: 'process:hermes-agent',
      );
      notifyListeners();
    }
  }

  @override
  Future<void> closeConnection() async {
    await _killActiveProcess();
    _connection = StreamingConnection.disconnected();
    notifyListeners();
  }

  /// Kill the currently active process (if any).
  Future<void> _killActiveProcess({Duration timeout = const Duration(seconds: 5)}) async {
    final proc = _activeProcess;
    if (proc == null) return;

    _activeProcess = null;
    try {
      proc.kill(ProcessSignal.sigint);
      await Future.any([
        proc.exitCode.timeout(timeout),
        Future.delayed(timeout),
      ]);
      if (proc.kill(ProcessSignal.sigterm)) {
        await Future.delayed(const Duration(seconds: 1));
        proc.kill(ProcessSignal.sigkill);
      }
    } catch (_) {
      // Force kill as last resort
      try { proc.kill(ProcessSignal.sigkill); } catch (_) {}
    }
  }

  @override
  Future<bool> testConnection() async {
    try {
      await _resolveAgentPath();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableModels() async {
    // The agent resolves its model internally — we just expose a default.
    return ['default'];
  }

  @override
  Stream<StreamingMessage> streamResponse({
    required String prompt,
    required String model,
    required String conversationId,
    List<Map<String, String>>? history,
  }) async* {
    if (_disposed) return;

    String? agentPath;
    try {
      agentPath = await _resolveAgentPath();
    } catch (e) {
      final errorMsg = StreamingMessage.error(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationId: conversationId,
        error: 'Cannot find hermes-agent: $e',
        sequence: 0,
      );
      _messageController.add(errorMsg);
      yield errorMsg;
      return;
    }

    _connection = StreamingConnection.streaming('process:hermes-agent');
    notifyListeners();

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final output = StringBuffer();
    int sequence = 0;
    _restartAttempts = 0;

    while (_restartAttempts < 2) {
      try {
        // Spawn hermes-agent chat -q for a single non-interactive query
        _activeProcess = await Process.start(
          agentPath,
          ['chat', '-q', prompt],
          runInShell: true,
        );

        // Read stdout line by line
        _activeProcess!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(output.writeln);

        // Read stderr for diagnostics
        final stderrLines = <String>[];
        _activeProcess!.stderr
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen(stderrLines.add);

        final exitCode = await _activeProcess!.exitCode;
        _activeProcess = null;

        if (exitCode != 0 && output.isEmpty) {
          _restartAttempts++;
          if (_restartAttempts < 2) {
            debugPrint('[HermesProcess] Process exited with code $exitCode, '
                'restarting (attempt $_restartAttempts)...');
            output.clear();
            continue;
          }
          final errorDetail = stderrLines.isNotEmpty
              ? stderrLines.join('; ')
              : 'exit code $exitCode';
          final errorMsg = StreamingMessage.error(
            id: messageId,
            conversationId: conversationId,
            error: 'hermes-agent failed after $_restartAttempts retries: $errorDetail',
            sequence: sequence,
          );
          _messageController.add(errorMsg);
          yield errorMsg;
          return;
        }

        // Yield the complete response as a single chunk
        if (output.isNotEmpty) {
          yield StreamingMessage.chunk(
            id: messageId,
            conversationId: conversationId,
            chunk: output.toString().trim(),
            sequence: sequence,
          );
        }

        // Signal completion
        final completeMsg = StreamingMessage.complete(
          id: messageId,
          conversationId: conversationId,
          sequence: sequence,
        );
        _messageController.add(completeMsg);
        yield completeMsg;

        _connection = StreamingConnection.connected('process:hermes-agent');
        notifyListeners();
        return;
      } on ProcessException catch (e) {
        _restartAttempts++;
        if (_restartAttempts < 2) {
          debugPrint('[HermesProcess] ProcessException, restarting: $e');
          continue;
        }
        _connection = StreamingConnection.error(
          'Process error after $_restartAttempts retries: $e',
          endpoint: 'process:hermes-agent',
        );
        notifyListeners();
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error: 'Process error: $e',
          sequence: sequence,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      } on Exception catch (e) {
        _restartAttempts++;
        if (_restartAttempts < 2) {
          debugPrint('[HermesProcess] Stream error, restarting: $e');
          continue;
        }
        _connection = StreamingConnection.error(
          'Stream error after $_restartAttempts retries: $e',
          endpoint: 'process:hermes-agent',
        );
        notifyListeners();
        final errorMsg = StreamingMessage.error(
          id: messageId,
          conversationId: conversationId,
          error: 'Stream error: $e',
          sequence: sequence,
        );
        _messageController.add(errorMsg);
        yield errorMsg;
        return;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _killActiveProcess();
    _messageController.close();
    _connection = StreamingConnection.disconnected();
    super.dispose();
  }
}
