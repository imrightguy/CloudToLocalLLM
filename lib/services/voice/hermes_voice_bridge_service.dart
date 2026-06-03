import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'voice_conversation_service.dart';

class HermesVoiceBridgeService {
  HermesVoiceBridgeService({
    required VoiceConversationService voiceConversationService,
    Duration pollInterval = const Duration(seconds: 1),
    String? habitMonitorPath,
  })  : _voiceConversationService = voiceConversationService,
        _pollInterval = pollInterval,
        _habitMonitorPath = habitMonitorPath;

  final VoiceConversationService _voiceConversationService;
  final Duration _pollInterval;
  final String? _habitMonitorPath;
  static const String _healthUrl = 'http://127.0.0.1:8642/health';

  Timer? _pollTimer;
  bool _started = false;
  bool _disposed = false;

  void start() {
    if (_started || _disposed || kIsWeb) {
      return;
    }
    _started = true;
    _pollOnce();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _started = false;
  }

  void dispose() {
    _disposed = true;
    stop();
  }

  Future<void> _pollOnce() async {
    if (_disposed) {
      return;
    }
    try {
      // First, check Hermes gateway health directly
      final hermesAlive = await _checkHermesHealth();

      // Then try file-based state from habit-monitor
      final baseDir = _habitMonitorDir();
      final voiceStatusFile = File('${baseDir.path}/voice_reactor_status.json');
      final convoStateFile = File('${baseDir.path}/conversation_state.json');
      final sensorStatusFile = File('${baseDir.path}/status.json');

      if (!await voiceStatusFile.exists()) {
        // No files yet — report based on direct health check
        if (_disposed) {
          return;
        }
        _voiceConversationService.applyExternalSnapshot(
          mode: VoiceConversationMode.idle,
          liveBridgeConnected: hermesAlive,
          liveBridgeStatus: hermesAlive
              ? 'live Hermes bridge'
              : 'waiting for Hermes',
          lastUserTranscript: '',
          lastAssistantReply: '',
        );
        return;
      }

      // Files exist — read them for conversation state, but override
      // the running flag with the direct health check so it's always accurate
      final voiceStatus = await _readJson(voiceStatusFile);
      final convoState = await _readJson(convoStateFile);
      final sensorStatus = await _readJson(sensorStatusFile);

      final engagedUntil = _parseEngagedUntil(convoState, voiceStatus);
      final transcript = _pickFirstString([
        convoState['last_user_transcript'],
        voiceStatus['last_transcript_preview'],
      ]);
      final reply = _pickFirstString([
        convoState['last_reply'],
        voiceStatus['last_spoken'],
        voiceStatus['last_candidate_response'],
      ]);

      final mode = _deriveMode(
        voiceStatus: voiceStatus,
        sensorStatus: sensorStatus,
        engagedUntil: engagedUntil,
      );

      final reactorRunning = hermesAlive || voiceStatus['running'] == true;
      final statusLabel = reactorRunning
          ? 'live Hermes bridge'
          : 'Hermes reactor seen but not running';

      if (_disposed) {
        return;
      }
      _voiceConversationService.applyExternalSnapshot(
        mode: mode,
        liveBridgeConnected: reactorRunning,
        liveBridgeStatus: statusLabel,
        engagedUntil: engagedUntil,
        lastUserTranscript: transcript,
        lastAssistantReply: reply,
      );
    } catch (e) {
      if (_disposed) {
        return;
      }
      _voiceConversationService.applyExternalSnapshot(
        mode: VoiceConversationMode.idle,
        liveBridgeConnected: false,
        liveBridgeStatus: 'bridge error: $e',
      );
    }
  }

  /// Check if the Hermes gateway health endpoint is alive.
  Future<bool> _checkHermesHealth() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(_healthUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        return false;
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body);
      return decoded is Map && decoded['status'] == 'ok';
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }

  Directory _habitMonitorDir() {
    final habitMonitorPath = _habitMonitorPath;
    if (habitMonitorPath != null && habitMonitorPath.isNotEmpty) {
      return Directory(habitMonitorPath);
    }
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('HOME environment variable is not available');
    }
    return Directory('$home/.hermes/habit-monitor');
  }

  Future<Map<String, dynamic>> _readJson(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return <String, dynamic>{};
  }

  DateTime? _parseEngagedUntil(
    Map<String, dynamic> convoState,
    Map<String, dynamic> voiceStatus,
  ) {
    final engagedRaw =
        convoState['engaged_until'] ?? voiceStatus['engaged_until'];
    if (engagedRaw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (engagedRaw * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (engagedRaw is String && engagedRaw.isNotEmpty) {
      return DateTime.tryParse(engagedRaw)?.toLocal();
    }
    return null;
  }

  String _pickFirstString(List<dynamic> values) {
    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  VoiceConversationMode _deriveMode({
    required Map<String, dynamic> voiceStatus,
    required Map<String, dynamic> sensorStatus,
    required DateTime? engagedUntil,
  }) {
    final now = DateTime.now();
    final lastSpoken = _pickFirstString([voiceStatus['last_spoken']]);
    final lastUpdatedAt = _parseUpdatedAt(voiceStatus['updated_at']);
    final speechLike = _speechLike(sensorStatus);
    final skipReason = voiceStatus['skip_reason']?.toString();

    if (lastSpoken.isNotEmpty &&
        lastUpdatedAt != null &&
        now.difference(lastUpdatedAt) < const Duration(seconds: 4)) {
      return VoiceConversationMode.speaking;
    }

    if (engagedUntil != null && engagedUntil.isAfter(now)) {
      return VoiceConversationMode.engaged;
    }

    if (speechLike) {
      return VoiceConversationMode.listening;
    }

    if (skipReason == 'cooldown') {
      return VoiceConversationMode.coolingDown;
    }

    return VoiceConversationMode.idle;
  }

  DateTime? _parseUpdatedAt(dynamic raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (raw * 1000).round(),
        isUtc: true,
      ).toLocal();
    }
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    return null;
  }

  bool _speechLike(Map<String, dynamic> sensorStatus) {
    final lastObservation = sensorStatus['last_observation'];
    if (lastObservation is! Map<String, dynamic>) {
      return false;
    }
    final audio = lastObservation['audio'];
    if (audio is! Map<String, dynamic>) {
      return false;
    }
    final metrics = audio['metrics'];
    if (metrics is! Map<String, dynamic>) {
      return false;
    }
    return metrics['speech_like'] == true;
  }
}
