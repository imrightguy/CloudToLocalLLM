import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Local TTS service using Piper TTS HTTP endpoint.
class LocalTtsService {
  final String _baseUrl = 'http://127.0.0.1:8645';
  final http.Client _client = http.Client();

  bool _available = false;
  bool get isAvailable => _available;

  /// Check if local TTS server is reachable.
  Future<bool> checkAvailability() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));

      _available = response.statusCode == 200;
    } catch (e) {
      debugPrint('[LocalTTS] Server not available: $e');
      _available = false;
    }
    return _available;
  }

  /// Synthesize text to a WAV file.
  Future<String?> synthesize(String text, {String? outputPath}) async {
    await checkAvailability();
    if (!_available) return null;

    outputPath ??= '${Directory.systemTemp.path}/tts_${DateTime.now().millisecondsSinceEpoch}.wav';

    try {
      final uri = Uri.parse(
        '$_baseUrl/tts?text=${Uri.encodeComponent(text)}',
      );

      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[LocalTTS] Server error: ${response.statusCode}');
        return null;
      }

      final file = File(outputPath);
      await file.writeAsBytes(response.bodyBytes);

      _cleanupOldFiles();

      final size = await file.length();
      if (size == 0) {
        debugPrint('[LocalTTS] Empty WAV file');
        await file.delete();
        return null;
      }

      debugPrint('[LocalTTS] Generated $outputPath ($size bytes)');
      return outputPath;
    } catch (e) {
      debugPrint('[LocalTTS] Synthesis failed: $e');
      return null;
    }
  }

  Future<Uint8List?> synthesizeRaw(String text) async {
    await checkAvailability();
    if (!_available) return null;

    try {
      final uri = Uri.parse(
        '$_baseUrl/tts?text=${Uri.encodeComponent(text)}',
      );

      final response = await _client.get(uri).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('[LocalTTS] Server error: ${response.statusCode}');
        return null;
      }

      debugPrint('[LocalTTS] Synthesized ${response.bodyBytes.length} bytes');
      return response.bodyBytes;
    } catch (e) {
      debugPrint('[LocalTTS] Raw synthesis failed: $e');
      return null;
    }
  }

  void _cleanupOldFiles() {
    final dir = Directory.systemTemp;
    try {
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.startsWith('${dir.path}/tts_'))
          .toList()
        ..sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));

      while (files.length > 50) {
        files.removeAt(0).deleteSync();
      }
    } catch (_) {}
  }

  void dispose() {
    _client.close();
  }
}