import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../models/conversation.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'local_conversation_storage.dart';

/// Security exception for unauthorized access attempts
class SecurityException implements Exception {
  final String message;
  SecurityException(this.message);

  @override
  String toString() => 'SecurityException: $message';
}

/// Conversation storage service that prioritizes local storage on Desktop
/// and falls back to Cloud API when available.
class ConversationStorageService {
  final AuthService? _authService;
  final LocalConversationStorage _localStorage = LocalConversationStorage();
  bool _isInitialized = false;
  final Dio _dio = Dio();

  ConversationStorageService({AuthService? authService})
      : _authService = authService {
    _setupDio();
  }

  void _setupDio() {
    _dio.options.baseUrl = AppConfig.apiBaseUrl;
    _dio.options.connectTimeout = AppConfig.apiTimeout;
    _dio.options.receiveTimeout = AppConfig.apiTimeout;
  }

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[ConversationStorage] Already initialized, skipping');
      return;
    }

    try {
      debugPrint('[ConversationStorage] Initializing local and cloud storage');
      _isInitialized = true;
      debugPrint('[ConversationStorage] Service initialized');
    } catch (e, stackTrace) {
      debugPrint('[ConversationStorage] Failed to initialize: $e');
      _isInitialized = true;
    }
  }

  /// Save a list of conversations to both Local and Cloud
  Future<void> saveConversations(List<Conversation> conversations) async {
    // 1. Always save locally first (ensures persistence after restart)
    if (!kIsWeb) {
      await _localStorage.saveConversations(conversations);
    }

    // 2. Sync to cloud if authenticated
    if (_authService?.isAuthenticated.value == true) {
      for (final conversation in conversations) {
        try {
          await saveConversation(conversation);
        } catch (e) {
          debugPrint('[ConversationStorage] Cloud sync failed for ${conversation.id}: $e');
          // Don't throw - local is already saved
        }
      }
    }
  }

  /// Load all conversations
  Future<List<Conversation>> loadConversations() async {
    // 1. On Desktop, try local storage first
    if (!kIsWeb) {
      final localConversations = await _localStorage.loadConversations();
      if (localConversations.isNotEmpty) {
        debugPrint('[ConversationStorage] Loaded ${localConversations.length} conversations from local storage');
        return localConversations;
      }
    }

    // 2. Try loading from API as fallback or if on Web
    return await _loadFromApi();
  }

  /// Load conversations from Cloud API
  Future<List<Conversation>> _loadFromApi() async {
    if (_authService?.isAuthenticated.value != true) return [];
    
    try {
      final headers = await _getAuthHeaders();
      final response = await _dio.get('/api/conversations',
          options: Options(headers: headers));

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final conversationsData = data['conversations'] as List<dynamic>? ?? [];

        final conversations = <Conversation>[];
        for (final convData in conversationsData) {
          // Reconstructing conversation from basic info
          conversations.add(Conversation.fromJson({
            'id': convData['id'],
            'title': convData['title'],
            'model': convData['model'],
            'createdAt': convData['created_at'],
            'updatedAt': convData['updated_at'],
            'metadata': convData['metadata'] ?? {},
            'messages': [], // Messages will be loaded on demand or use local
          }));
        }

        debugPrint('[ConversationStorage] Loaded ${conversations.length} conversations from API');
        return conversations;
      }
    } catch (e) {
      debugPrint('[ConversationStorage] Error loading from API: $e');
    }
    return [];
  }

  /// Fetch full conversation with messages
  Future<Conversation?> loadConversationWithMessages(
      String conversationId) async {
    // Local storage stores full conversations, so we don't need a separate fetch for messages
    // but we'll maintain the API structure for cloud syncing
    try {
      if (_authService?.isAuthenticated.value == true) {
        final headers = await _getAuthHeaders();
        final response = await _dio.get('/api/conversations/$conversationId',
            options: Options(headers: headers));

        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final convData = data['conversation'] as Map<String, dynamic>;
          return Conversation.fromJson(convData);
        }
      }
    } catch (e) {
      debugPrint('[ConversationStorage] Error loading detail from API: $e');
    }
    return null;
  }

  /// Save a single conversation via API
  Future<void> saveConversation(Conversation conversation) async {
    if (_authService?.isAuthenticated.value != true) return;

    try {
      final headers = await _getAuthHeaders();
      final body = conversation.toJson();

      final response = await _dio.put('/api/conversations/${conversation.id}',
          data: body, options: Options(headers: headers));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[ConversationStorage] Saved to cloud: ${conversation.title}');
      }
    } catch (e) {
      debugPrint('[ConversationStorage] Cloud save error: $e');
    }
  }

  /// Delete a conversation
  Future<void> deleteConversation(String conversationId) async {
    // Delete locally
    if (!kIsWeb) {
      final conversations = await _localStorage.loadConversations();
      conversations.removeWhere((c) => c.id == conversationId);
      await _localStorage.saveConversations(conversations);
    }

    // Delete from cloud
    if (_authService?.isAuthenticated.value == true) {
      try {
        final headers = await _getAuthHeaders();
        await _dio.delete('/api/conversations/$conversationId',
            options: Options(headers: headers));
      } catch (e) {
        debugPrint('[ConversationStorage] Cloud delete error: $e');
      }
    }
  }

  /// Clear all conversations
  Future<void> clearAllConversations() async {
    if (!kIsWeb) {
      await _localStorage.clearAll();
    }
    
    if (_authService?.isAuthenticated.value == true) {
      try {
        final conversations = await _loadFromApi();
        for (final conv in conversations) {
          await deleteConversation(conv.id);
        }
      } catch (e) {
        debugPrint('[ConversationStorage] Cloud clear error: $e');
      }
    }
  }

  // ========== Helpers ==========

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService?.getAccessToken();
    if (token == null) throw SecurityException('No access token');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  bool get isInitialized => _isInitialized;

  Future<Map<String, dynamic>> getDatabaseStats() async {
    final conversations = await loadConversations();
    return {
      'total_conversations': conversations.length,
      'storage_type': kIsWeb ? 'Cloud' : 'Local + Hybrid',
      'last_updated': DateTime.now().toIso8601String(),
    };
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }
}
