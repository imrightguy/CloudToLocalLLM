import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/conversation.dart';

/// Local storage service for conversations using JSON files
class LocalConversationStorage {
  static const String _fileName = 'conversations.json';

  /// Get the local file for storing conversations
  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, 'CloudToLocalLLM', _fileName);
    final file = File(path);

    // Ensure directory exists
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    return file;
  }

  /// Save all conversations to local storage
  Future<void> saveConversations(List<Conversation> conversations) async {
    try {
      final file = await _getLocalFile();
      final jsonData = conversations.map((c) => c.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
      debugPrint(
          '[LocalChatStorage] Saved ${conversations.length} conversations to ${file.path}');
    } catch (e) {
      debugPrint('[LocalChatStorage] Error saving conversations: $e');
    }
  }

  /// Load all conversations from local storage
  Future<List<Conversation>> loadConversations() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final List<dynamic> jsonData = jsonDecode(content);
      return jsonData.map((data) => Conversation.fromJson(data)).toList();
    } catch (e) {
      debugPrint('[LocalChatStorage] Error loading conversations: $e');
      return [];
    }
  }

  /// Clear all local conversations
  Future<void> clearAll() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[LocalChatStorage] Error clearing storage: $e');
    }
  }
}
