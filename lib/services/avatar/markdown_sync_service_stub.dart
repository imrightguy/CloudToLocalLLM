import 'package:flutter/foundation.dart';

class MarkdownSyncService {
  Future<void> syncPersonality(dynamic profile) async {
    debugPrint(
        '[MarkdownSync] syncPersonality called (stub - web not supported)');
  }

  Future<void> syncMemory() async {
    debugPrint('[MarkdownSync] syncMemory called (stub - web not supported)');
  }

  Future<void> syncContext() async {
    debugPrint('[MarkdownSync] syncContext called (stub - web not supported)');
  }

  Future<void> syncAll(dynamic profile) async {
    debugPrint('[MarkdownSync] syncAll called (stub - web not supported)');
  }

  Future<dynamic> loadPersonalityFromMarkdown() async {
    debugPrint(
        '[MarkdownSync] loadPersonalityFromMarkdown called (stub - web not supported)');
    return null;
  }
}
