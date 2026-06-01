import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'voice_conversation_service.dart';

/// UI-facing state for the local voice input path.
class LocalVoiceInputSnapshot {
  const LocalVoiceInputSnapshot({
    required this.isCapturing,
    required this.transcriptInProgress,
    required this.lastFullTranscript,
    required this.lastError,
    required this.sttStatus,
  });

  final bool isCapturing;
  final String transcriptInProgress;
  final String lastFullTranscript;
  final String? lastError;
  final String sttStatus;
}

/// Minimal local mic capture service.
///
/// This intentionally does NOT claim backend-only capabilities the host does not have.
/// Right now on this machine:
/// - `parec` is available
/// - `ffmpeg` is available
/// - no local whisper binary is installed
/// - no confirmed local STT endpoint is listening
///
/// Until a real STT path is wired, audio capture is stubbed and the UI surfaces
/// the actual missing capability instead of silently failing.
class LocalVoiceInputService {
  LocalVoiceInputService({
    required VoiceConversationService voiceConversationService,
    this.sttUrl = 'http://127.0.0.1:8643/v1/audio/transcriptions',
    this.captureCommand = 'parec',
    this.sampleRate = 16000,
  })  : _voiceConversationService = voiceConversationService;

  final VoiceConversationService _voiceConversationService;
  final String sttUrl;
  final String captureCommand;
  final int sampleRate;

  Process? _captureProcess;
  bool _isCapturing = false;
  bool _disposed = false;

  String _partialBuffer = '';
  String _lastFullTranscript = '';
  String? _lastError;
  String _sttStatus = 'unconfigured';

  bool get isCapturing => _isCapturing;
  String get sttStatus => _sttStatus;

  LocalVoiceInputSnapshot get snapshot => LocalVoiceInputSnapshot(
        isCapturing: _isCapturing,
        transcriptInProgress: _partialBuffer,
        lastFullTranscript: _lastFullTranscript,
        lastError: _lastError,
        sttStatus: _sttStatus,
      );

  Future<bool> startCapture() async {
    if (_isCapturing || _disposed || kIsWeb) return false;

    final hasCapture = await _hasCommand(captureCommand);
    final hasStt = await _reachableStt();

    if (!hasCapture || !hasStt) {
      _lastError = [
        if (!hasCapture) 'missing capture command: $captureCommand',
        if (!hasStt) 'STT endpoint unreachable: $sttUrl',
      ].join('; ');
      _sttStatus = 'unavailable';
      return false;
    }

    try {
      _captureProcess = await Process.start(
        captureCommand,
        [
          '--rate=$sampleRate',
          '--format=s16le',
          '--channels=1',
          '--raw',
          '--device=@DEFAULT_SOURCE@',
        ],
      );

      _isCapturing = true;
      _lastError = null;
      _sttStatus = 'capturing';

      _captureProcess.stdout!.listen(
        _onPcm,
        onError: _onPcmError,
        onDone: _onPcmDone,
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      _lastError = 'Capture start failed: $e';
      _isCapturing = false;
      _sttStatus = 'error';
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    _isCapturing = false;
    _captureProcess?.kill();
    _captureProcess = null;
    _sttStatus = 'stopped';
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopCapture();
  }

  Future<void> _onPcmDone() async {
    _sttStatus = 'idle';
    await _flushTranscript();
  }

  void _onPcmError(Object e) {
    _lastError = 'Capture stream error: $e';
  }

  Future<bool> _reachableStt() async {
    try {
      final result = await Process.run(
        'curl',
        [
          '-s',
          '--connect-timeout',
          '2',
          '--max-time',
          '3',
          '-X',
          'POST',
          sttUrl,
          '-F',
          'file=@/dev/null',
          '-F',
          'model=whisper-1',
          '-F',
          'response_format=json',
        ],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasCommand(String command) async {
    try {
      final result = await Process.run('command', ['-v', command]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _onPcm(List<int> data) {
    _partialBuffer += const Utf8Decoder().convert(data);
  }

  Future<void> _flushTranscript() async {
    final text = _partialBuffer.trim();
    _partialBuffer = '';
    if (text.isEmpty) return;

    if (_voiceConversationService.shouldPreferConversationalPath(text)) {
      _voiceConversationService.noteWakePhrase(text);
    }

    _lastFullTranscript = text;
  }
}
