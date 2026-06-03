import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Local TTS service using Piper TTS server at :8645.
///
/// Sends text to the local Piper TTS HTTP server at the OpenAI-compatible
/// /v1/audio/speech endpoint and returns the WAV audio file path.
/// Falls back gracefully if the server is unreachable.
class LocalTtsService {
  LocalTtsService({
    this.ttsUrl = 'http://127.0.0.1:8645/v1/audio/speech',
    this.healthUrl = 'http://127.0.0.1:8645/health',
    this.outputDir,
    Duration timeout = const Duration(seconds: 30),
  }) : _timeout = timeout;

  final String ttsUrl;
  final String healthUrl;
  final Directory? outputDir;
  final Duration _timeout;

  bool _available = false;
  bool _checked = false;

  /// Whether the Piper TTS server is reachable.
  Future<bool> get isAvailable async {
    if (_checked) return _available;
    _checked = true;
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(Uri.parse(healthUrl));
      final response = await request.close();
      _available = response.statusCode == 200;
      client.close(force: true);
    } catch (_) {
      _available = false;
    }
    return _available;
  }

  /// Synthesize text to a WAV file.
  ///
  /// Returns the path to the WAV file, or null if synthesis failed.
  Future<String?> synthesize(String text) async {
    if (!await isAvailable) {
      debugPrint('[LocalTTS] Server not available');
      return null;
    }

    final dir = outputDir ??
        Directory(
          '${Platform.environment['HOME'] ?? '/tmp'}/.cache/cloudtolocalllm/tts',
        );
    await dir.create(recursive: true);

    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final outputPath = '${dir.path}/speech_$timestamp.wav';

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final body = jsonEncode({
        'input': text,
        'model': 'piper-tts',
        'response_format': 'wav',
      });

      final request = await client.postUrl(Uri.parse(ttsUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Content-Length', body.length.toString());
      request.add(utf8.encode(body));

      final response = await request.close().timeout(_timeout);

      if (response.statusCode != 200) {
        final err = await response.transform(utf8.decoder).join();
        debugPrint('[LocalTTS] Error ${response.statusCode}: $err');
        client.close(force: true);
        return null;
      }

      final file = File(outputPath);
      await file.openWrite(mode: FileMode.write).addStream(response);
      client.close(force: true);

      final size = await file.length();
      if (size == 0) {
        debugPrint('[LocalTTS] Empty WAV file');
        await file.delete();
        return null;
      }

      debugPrint('[LocalTTS] Generated $outputPath (${size} bytes)');
      return outputPath;
    } catch (e) {
      debugPrint('[LocalTTS] Synthesis failed: $e');
      return null;
    }
  }

  /// Synthesize to WAV bytes in memory (for streaming).
  Future<Uint8List?> synthesizeRaw(String text) async {
    if (!await isAvailable) return null;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);

      final body = jsonEncode({
        'input': text,
        'model': 'piper-tts',
        'response_format': 'wav',
      });

      final request = await client.postUrl(Uri.parse(ttsUrl));
      request.headers.set('Content-Type', 'application/json');
      request.headers.set('Content-Length', body.length.toString());
      request.add(utf8.encode(body));

      final response = await request.close().timeout(_timeout);

      if (response.statusCode != 200) {
        client.close(force: true);
        return null;
      }

      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(),
        (b, chunk) => b..add(chunk),
      );
      client.close(force: true);
      return bytes.takeBytes();
    } catch (e) {
      debugPrint('[LocalTTS] Raw synthesis failed: $e');
      return null;
    }
  }

  /// Play the synthesized audio via aplay/paplay.
  Future<bool> play(String text) async {
    final wavBytes = await synthesizeRaw(text);
    if (wavBytes == null || wavBytes.isEmpty) return false;

    try {
      final process = await Process.start(
        'paplay',
        ['--raw', '--rate=22050', '--channels=1', '--format=s16le'],
      );
      process.stdin.add(wavBytes);
      await process.stdin.close();
      final exitCode = await process.exitCode;
      return exitCode == 0;
    } catch (e) {
      // Try aplay fallback
      try {
        final tempFile = File('/tmp/_hermes_tts_play.wav');
        await tempFile.writeAsBytes(wavBytes);
        final result = await Process.run('aplay', [tempFile.path]);
        await tempFile.delete();
        return result.exitCode == 0;
      } catch (e2) {
        debugPrint('[LocalTTS] Playback failed: $e2');
        return false;
      }
    }
  }

  void reset() {
    _checked = false;
    _available = false;
  }
}
