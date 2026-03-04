import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:uuid/uuid.dart';

/// Memory Service
/// Manages avatar long-term memory with vector embeddings for semantic search
class MemoryService {
  final LocalBrain database;
  final Uuid _uuid = const Uuid();

  bool _isInitialized = false;
  String? _lastError;

  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;

  MemoryService({required this.database});

  /// Initialize the memory service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[MemoryService] Already initialized, skipping');
      return;
    }

    debugPrint('[MemoryService] Initializing...');
    _isInitialized = true;
    _lastError = null;
    debugPrint('[MemoryService] Initialized successfully');
  }

  /// Store a memory with embedding
  Future<String> storeMemory({
    required String conversationId,
    required String content,
    String? summary,
    List<double>? embedding,
  }) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    final id = _uuid.v4();
    debugPrint('[MemoryService] Storing memory: $id');

    try {
      // For now, store empty embedding array
      // TODO: Generate actual embedding using text embedding model
      final embeddingJson =
          embedding != null ? jsonEncode(embedding) : jsonEncode(<double>[]);

      await database.insertMemory(
        ConversationMemoriesCompanion.insert(
          id: id,
          conversationId: conversationId,
          content: content,
          embedding: embeddingJson,
          summary: Value(summary),
        ),
      );

      _lastError = null;
      debugPrint('[MemoryService] Memory stored: $id');
      return id;
    } catch (e) {
      _lastError = 'Failed to store memory: $e';
      debugPrint('[MemoryService] $_lastError');
      rethrow;
    }
  }

  /// Search memories by content (semantic search)
  Future<List<ConversationMemory>> searchMemories(String query) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Searching memories for: $query');
    try {
      final results = await database.searchMemoriesByContent(query);
      _lastError = null;
      debugPrint('[MemoryService] Found ${results.length} memories');
      return results;
    } catch (e) {
      _lastError = 'Failed to search memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Get all memories for a specific conversation
  Future<List<ConversationMemory>> getMemoriesForConversation(
      String conversationId) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Getting memories for: $conversationId');
    try {
      final memories =
          await database.getMemoriesForConversation(conversationId);
      _lastError = null;
      debugPrint('[MemoryService] Found ${memories.length} memories');
      return memories;
    } catch (e) {
      _lastError = 'Failed to get memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Get recent memories across all conversations
  Future<List<ConversationMemory>> getRecentMemories({int limit = 50}) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Getting recent memories (limit: $limit)');
    try {
      final memories = await database.getRecentMemories(limit: limit);
      _lastError = null;
      debugPrint('[MemoryService] Found ${memories.length} recent memories');
      return memories;
    } catch (e) {
      _lastError = 'Failed to get recent memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return [];
    }
  }

  /// Delete all memories for a conversation
  Future<int> deleteMemoriesForConversation(String conversationId) async {
    if (!_isInitialized) {
      final error = 'Service not initialized';
      _lastError = error;
      debugPrint('[MemoryService] $error');
      throw StateError(error);
    }

    debugPrint('[MemoryService] Deleting memories for: $conversationId');
    try {
      final count =
          await database.deleteMemoriesForConversation(conversationId);
      _lastError = null;
      debugPrint('[MemoryService] Deleted $count memories');
      return count;
    } catch (e) {
      _lastError = 'Failed to delete memories: $e';
      debugPrint('[MemoryService] $_lastError');
      return 0;
    }
  }

  /// Dispose of the memory service
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[MemoryService] Disposing...');
    _isInitialized = false;
    _lastError = null;
    debugPrint('[MemoryService] Disposed successfully');
  }
}
