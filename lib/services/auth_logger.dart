// Simple auth logger for CloudToLocalLLM
import 'package:flutter/foundation.dart';

class AuthLogger {
  static final List<String> _logs = [];

  static void info(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[INFO]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(' ');
    }
  }

  static void error(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[ERROR]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint('  ');
    }
  }

  static void debug(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[DEBUG]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint(' � ');
    }
  }

  static void warning(String message, [Map<String, dynamic>? data]) {
    final logEntry = '[WARNING]  ';
    _logs.add(logEntry);
    if (kDebugMode) {
      debugPrint('��  ');
    }
  }

  static List<String> getLogs() => List.from(_logs);
  static void clearLogs() => _logs.clear();
  static void downloadLogs() {} // Stub
}
