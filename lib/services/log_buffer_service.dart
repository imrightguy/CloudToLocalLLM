import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../utils/web_interop_stub.dart'
    if (dart.library.html) '../utils/web_interop.dart';

import '../config/app_config.dart';

/// Simple client-side log buffer that mirrors debug output into localStorage
/// and periodically uploads entries to the backend, where they are persisted
/// as plain text files on the container for easy retrieval.
class LogBufferService {
  static const String storageKey = 'app_client_log_buffer';
  static final LogBufferService instance = LogBufferService._internal();

  final int maxEntries;
  final Dio _dio;
  final List<Map<String, dynamic>> _pendingEntries = <Map<String, dynamic>>[];
  Timer? _flushTimer;
  bool _isFlushing = false;

  LogBufferService._internal()
      : maxEntries = 500,
        _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );

  void add(String message, {String level = 'INFO'}) {
    if (!kIsWeb) {
      return;
    }

    try {
      final storage = window.localStorage;
      final existing = storage[storageKey];
      final List<dynamic> logList = existing != null && existing.isNotEmpty
          ? (jsonDecode(existing) as List<dynamic>)
          : <dynamic>[];

      final logEntry = <String, dynamic>{
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
      };

      logList.add(logEntry);

      if (logList.length > maxEntries) {
        final start = logList.length - maxEntries;
        storage[storageKey] = jsonEncode(logList.sublist(start));
      } else {
        storage[storageKey] = jsonEncode(logList);
      }

      _enqueueForUpload(logEntry, level: level, rawMessage: message);
    } catch (e) {
      // Logging should never crash the app, but log the error for debugging
      debugPrint('[LogBuffer] ⚠ Failed to write log: $e');
    }
  }

  void clear() {
    if (!kIsWeb) {
      return;
    }
    try {
      window.localStorage.remove(storageKey);
    } catch (e) {
      debugPrint('[LogBuffer] ⚠ Failed to clear logs: $e');
    }
  }

  String? export() {
    if (!kIsWeb) {
      return null;
    }
    try {
      return window.localStorage[storageKey];
    } catch (_) {
      return null;
    }
  }

  void _enqueueForUpload(
    Map<String, dynamic> entry, {
    required String level,
    required String rawMessage,
  }) {
    if (!kIsWeb || AppConfig.apiBaseUrl.isEmpty) {
      return;
    }

    try {
      final url = window.location.href;
      final userAgent = window.navigator.userAgent;
      final payload = <String, dynamic>{
        'timestamp': entry['timestamp'],
        'level': level,
        'message': rawMessage,
        'url': url,
        'userAgent': userAgent,
      };

      _pendingEntries.add(payload);
      if (_pendingEntries.length > maxEntries) {
        _pendingEntries.removeRange(0, _pendingEntries.length - maxEntries);
      }

      _scheduleFlush();
    } catch (_) {
      // Ignore failures when gathering metadata.
    }
  }

  void _scheduleFlush({Duration delay = const Duration(seconds: 3)}) {
    if (_flushTimer?.isActive == true || _isFlushing) {
      return;
    }

    _flushTimer = Timer(delay, _flushPendingEntries);
  }

  Future<void> _flushPendingEntries() async {
    if (!kIsWeb || _isFlushing || _pendingEntries.isEmpty) {
      return;
    }

    _isFlushing = true;
    List<Map<String, dynamic>> batch = <Map<String, dynamic>>[];
    try {
      // Send at most 100 entries per batch to keep payloads small.
      final batchSize =
          _pendingEntries.length > 100 ? 100 : _pendingEntries.length;
      batch = List<Map<String, dynamic>>.from(_pendingEntries.take(batchSize));
      _pendingEntries.removeRange(0, batchSize);

      await _dio.post(
        '/client-logs', // Removed /api prefix since baseUrl is already api subdomain
        data: {'entries': batch, 'source': 'flutter-web'},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
    } catch (_) {
      // Requeue entries so they can be retried later.
      _pendingEntries.insertAll(0, batch);
    } finally {
      _isFlushing = false;
      if (_pendingEntries.isNotEmpty) {
        _scheduleFlush(delay: const Duration(seconds: 10));
      }
    }
  }
}
