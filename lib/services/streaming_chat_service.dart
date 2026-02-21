import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/streaming_message.dart';

import 'streaming_service.dart';

import 'connection_manager_service.dart';
import 'conversation_storage_service.dart';
import 'auth_service.dart';
import '../utils/logger.dart';

/// Enhanced chat service with real-time streaming support
///
/// Provides progressive message streaming, real-time UI updates,
/// and integration with the tunnel manager for connection routing.
class StreamingChatService extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;
  final ConversationStorageService _storageService;

  StreamingChatService(
    this._connectionManager,
    AuthService authService,
  ) : _storageService = ConversationStorageService(authService: authService) {
    _initializeService();
  }

  List<Conversation> _conversations = [];
  Conversation? _currentConversation;
  String? _selectedModel = null;
  bool _isLoading = false;
  bool _isStreaming = false;

  // Streaming state
  final BehaviorSubject<String> _streamingContentSubject =
      BehaviorSubject<String>.seeded('');
  final BehaviorSubject<String> _streamingReasoningSubject =
      BehaviorSubject<String>.seeded('');
  StreamSubscription<StreamingMessage>? _currentStreamSubscription;
  String _currentStreamingMessageId = '';

  // Getters
  List<Conversation> get conversations => List.unmodifiable(_conversations);
  Conversation? get currentConversation => _currentConversation;
  String? get selectedModel => _selectedModel;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  bool get hasConversations => _conversations.isNotEmpty;

  /// Stream of current streaming content for real-time UI updates
  Stream<String> get streamingContentStream => _streamingContentSubject.stream;

  /// Stream of current streaming reasoning for real-time UI updates
  Stream<String> get streamingReasoningStream =>
      _streamingReasoningSubject.stream;

  /// Initialize the service
  void _initializeService() {
    // Initialize storage service and load conversations
    _initializeStorage();

    // Listen to connection manager changes
    _connectionManager.addListener(_onConnectionManagerChanged);
  }

  /// Initialize storage service and load conversations
  Future<void> _initializeStorage() async {
    try {
      await _storageService.initialize();
      await _loadConversations();
      appLogger.debug('[StreamingChat] Storage service initialized');
    } catch (e) {
      appLogger.error('[StreamingChat] Failed to initialize storage', error: e);
      // Fall back to in-memory conversations
      await _loadConversations();
    }
  }

  /// Handle connection manager changes
  void _onConnectionManagerChanged() {
    // Update available models when connections change
    final availableModels = _connectionManager.availableModels;
    if (availableModels.isNotEmpty) {
      // Auto-select first model if none selected
      if (_selectedModel == null) {
        _selectedModel = availableModels.first;
        appLogger.debug('[StreamingChat] Auto-selected model: $_selectedModel');
        notifyListeners();
      }
    }
  }

  /// Load conversations from storage
  Future<void> _loadConversations() async {
    try {
      final loadedConversations = await _storageService.loadConversations();

      if (loadedConversations.isNotEmpty) {
        _conversations = loadedConversations;
        // Don't auto-select on startup to show Zoidbot Ready screen
        _currentConversation = null;
        appLogger.info(
          '[StreamingChat] Loaded ${_conversations.length} conversations from storage',
        );
      } else {
        // Create a sample conversation if none exist
        _createWelcomeConversation();
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Error loading conversations', error: e);
      // Fall back to creating a welcome conversation
      _createWelcomeConversation();
    }

    notifyListeners();
  }

  /// Create a welcome conversation when no conversations exist
  void _createWelcomeConversation() {
    // Ensure we have a model selected before creating conversation
    final availableModels = _connectionManager.availableModels;
    final modelToUse = _selectedModel ??
        (availableModels.isNotEmpty ? availableModels.first : 'default');

    // Update selected model if it was null
    if (_selectedModel == null && availableModels.isNotEmpty) {
      _selectedModel = availableModels.first;
      appLogger.debug(
        '[StreamingChat] Auto-selected model for welcome conversation: $_selectedModel',
      );
    }

    final sampleConversation = Conversation.create(
      title: 'Welcome Chat',
      model: modelToUse,
    );

    final welcomeMessage = Message.system(
      content:
          'Welcome to Zoidbot! I\'m ready to help you with any questions or tasks. What would you like to talk about?',
    );

    _conversations = [sampleConversation.addMessage(welcomeMessage)];
    // Don't auto-select to show Zoidbot Ready screen
    _currentConversation = null;

    // Save the welcome conversation
    _saveConversations();
  }

  /// Save conversations to storage
  void _saveConversations() {
    // Save asynchronously without blocking the UI
    _saveConversationsAsync().catchError((e) {
      appLogger.error('[StreamingChat] Error saving conversations', error: e);
    });
  }

  /// Save conversations to storage asynchronously
  Future<void> _saveConversationsAsync() async {
    try {
      await _storageService.saveConversations(_conversations);
      appLogger.debug(
        '[StreamingChat] Saved ${_conversations.length} conversations to storage',
      );
    } catch (e) {
      appLogger.error('[StreamingChat] Failed to save conversations', error: e);
      rethrow;
    }
  }

  /// Create a new conversation
  void createConversation() {
    final newConversation = Conversation.create(
      title: 'New Chat',
      model: _selectedModel,
    );

    _conversations.insert(0, newConversation);
    _currentConversation = newConversation;
    _saveConversations();
    notifyListeners();
  }

  /// Select a conversation
  void selectConversation(Conversation? conversation) {
    _currentConversation = conversation;

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    notifyListeners();
  }

  /// Select a conversation by ID (null to deselect)
  void selectConversationById(String? conversationId) {
    if (conversationId == null) {
      _currentConversation = null;
    } else {
      final index = _conversations.indexWhere((c) => c.id == conversationId);
      if (index != -1) {
        _currentConversation = _conversations[index];
      }
    }
    _cancelCurrentStream();
    notifyListeners();
  }

  /// Delete a conversation
  void deleteConversation(Conversation conversation) {
    _conversations.removeWhere((c) => c.id == conversation.id);

    if (_currentConversation?.id == conversation.id) {
      _currentConversation =
          _conversations.isNotEmpty ? _conversations.first : null;
    }

    _saveConversations();
    notifyListeners();
  }

  /// Update conversation title
  void updateConversationTitle(Conversation conversation, String newTitle) {
    final index = _conversations.indexWhere((c) => c.id == conversation.id);
    if (index != -1) {
      _conversations[index] = _conversations[index].updateTitle(newTitle);
      if (_currentConversation?.id == conversation.id) {
        _currentConversation = _conversations[index];
      }
      _saveConversations();
      notifyListeners();
    }
  }

  /// Set the selected model
  void setSelectedModel(String model) {
    _selectedModel = model;

    // Update current conversation's default model
    if (_currentConversation != null) {
      final index = _conversations.indexWhere(
        (c) => c.id == _currentConversation!.id,
      );
      if (index != -1) {
        _conversations[index] = _conversations[index].updateModel(model);
        _currentConversation = _conversations[index];
      }
    }

    notifyListeners();
  }

  /// Send a message with streaming support
  Future<void> sendMessage(String content) async {
    if (_currentConversation == null || content.trim().isEmpty) return;
    if (_selectedModel == null) {
      // Use gateway default model - don't require model selection
      appLogger
          .debug('[StreamingChat] No model selected, using gateway default');
    }

    // Cancel any ongoing streaming
    _cancelCurrentStream();

    _setLoading(true);
    _setStreaming(false);

    try {
      // Add user message
      final userMessage = Message.user(content: content.trim());
      _addMessageToCurrentConversation(userMessage);

      // Add streaming message placeholder for assistant
      final streamingModel = _selectedModel ?? 'default';
      final streamingMessage = Message.streaming(model: streamingModel);
      _addMessageToCurrentConversation(streamingMessage);
      _currentStreamingMessageId = streamingMessage.id;

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Get streaming service
      final streamingService = _getStreamingService();
      if (streamingService == null) {
        appLogger.warning(
          '[StreamingChat] No streaming service available, falling back to non-streaming chat',
        );
        await _fallbackToNonStreamingChat(content.trim());
        return;
      }

      // Start streaming
      _setStreaming(true);
      _streamingContentSubject.add('');
      _streamingReasoningSubject.add('');

      final conversationId = _currentConversation!.id;
      final messageStream = streamingService.streamResponse(
        prompt: content.trim(),
        model: streamingModel,
        conversationId: conversationId,
        history: history,
      );

      // Listen to streaming messages
      _currentStreamSubscription = messageStream.listen(
        _handleStreamingMessage,
        onError: _handleStreamingError,
        onDone: _handleStreamingComplete,
      );
    } catch (e) {
      appLogger.error('[StreamingChat] Error in sendMessage', error: e);

      // Remove streaming message if it was added
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isStreaming) {
          _removeLastMessage();
          appLogger.debug(
            '[StreamingChat] Removed streaming message due to error',
          );
        }
      }

      final errorModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
        model: errorModel,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    } finally {
      _setLoading(false);
      _setStreaming(false);
    }
  }

  /// Handle incoming streaming message chunks
  void _handleStreamingMessage(StreamingMessage streamingMessage) {
    if (streamingMessage.hasError) {
      _handleStreamingError(streamingMessage.error!);
      return;
    }

    if (streamingMessage.isComplete) {
      _handleStreamingComplete();
      return;
    }

    if (streamingMessage.isDataChunk) {
      // Update content
      if (streamingMessage.chunk.isNotEmpty) {
        final currentContent = _streamingContentSubject.value;
        final newContent = currentContent + streamingMessage.chunk;
        _streamingContentSubject.add(newContent);
      }

      // Update reasoning
      if (streamingMessage.reasoning != null &&
          streamingMessage.reasoning!.isNotEmpty) {
        final currentReasoning = _streamingReasoningSubject.value;
        final newReasoning = currentReasoning + streamingMessage.reasoning!;
        _streamingReasoningSubject.add(newReasoning);
      }

      // Update the streaming message in the conversation
      _updateStreamingMessage(
        _streamingContentSubject.value,
        _streamingReasoningSubject.value,
      );
    }
  }

  /// Handle streaming error
  void _handleStreamingError(dynamic error) {
    appLogger.error('[StreamingChat] Streaming error: $error');

    _setStreaming(false);
    _removeLastMessage();

    final errorModel = _selectedModel ?? 'default';
    final errorMessage = Message.assistant(
      content:
          'Sorry, I encountered an error while streaming: ${error.toString()}',
      model: errorModel,
      status: MessageStatus.error,
      error: error.toString(),
    );
    _addMessageToCurrentConversation(errorMessage);
  }

  /// Handle streaming completion
  void _handleStreamingComplete() {
    appLogger.debug('[StreamingChat] Streaming completed');

    _setStreaming(false);

    // Convert streaming message to final assistant message
    final finalContent = _streamingContentSubject.value;
    final finalReasoning = _streamingReasoningSubject.value;

    // Always remove the streaming placeholder if it exists
    if (_currentConversation != null &&
        _currentConversation!.messages.isNotEmpty &&
        _currentConversation!.messages.last.id == _currentStreamingMessageId) {
      _removeLastMessage();
    }

    if (finalContent.isNotEmpty || finalReasoning.isNotEmpty) {
      final completeModel = _selectedModel ?? 'default';
      final assistantMessage = Message.assistant(
        content: finalContent,
        reasoning: finalReasoning.isNotEmpty ? finalReasoning : null,
        model: completeModel,
      );
      _addMessageToCurrentConversation(assistantMessage);

      // Auto-rename conversation if it's the first message
      _autoRenameConversation();
    } else {
      appLogger
          .warning('[StreamingChat] Streaming completed with empty content');
    }

    // Clear streaming content
    _streamingContentSubject.add('');
    _streamingReasoningSubject.add('');
    _currentStreamingMessageId = '';
  }

  /// Update the streaming message content
  void _updateStreamingMessage(String content, String? reasoning) {
    if (_currentConversation == null || _currentStreamingMessageId.isEmpty) {
      return;
    }

    final conversationId = _currentConversation!.id;
    final index = _conversations.indexWhere((c) => c.id == conversationId);

    if (index != -1) {
      final conversation = _conversations[index];
      final messageIndex = conversation.messages.indexWhere(
        (m) => m.id == _currentStreamingMessageId,
      );

      if (messageIndex != -1) {
        final updatedMessage = conversation.messages[messageIndex].copyWith(
          content: content,
          reasoning: reasoning,
        );

        final updatedMessages = List<Message>.from(conversation.messages);
        updatedMessages[messageIndex] = updatedMessage;

        final updatedConversation = conversation.copyWith(
          messages: updatedMessages,
          updatedAt: DateTime.now(),
        );

        _conversations[index] = updatedConversation;
        _currentConversation = updatedConversation;
        notifyListeners();
      }
    }
  }

  /// Auto-rename the conversation if it's the first message
  Future<void> _autoRenameConversation() async {
    final conversation = _currentConversation;
    if (conversation == null || conversation.title != 'New Chat') {
      return;
    }

    // Only rename after the first user message and its assistant response
    if (conversation.userMessageCount != 1) {
      return;
    }

    final firstUserMessage =
        conversation.messages.firstWhere((m) => m.isUser).content;

    appLogger.debug(
      '[StreamingChat] Auto-renaming conversation based on: "$firstUserMessage"',
    );

    try {
      final prompt =
          'Generate a short, catchy title (max 5-6 words) for a conversation that starts with: "$firstUserMessage". Respond only with the title text, no quotes or prefix.';

      final renameModel = _selectedModel ?? 'default';
      final newTitle = await _connectionManager.sendChatMessage(
        model: renameModel,
        message: prompt,
        history: [], // Send as a fresh request to avoid context confusion
      );

      if (newTitle != null && newTitle.trim().isNotEmpty) {
        var cleanTitle =
            newTitle.trim().replaceAll('"', '').replaceAll("'", '');
        // Remove trailing punctuation if it's just a period
        if (cleanTitle.endsWith('.') && !cleanTitle.endsWith('...')) {
          cleanTitle = cleanTitle.substring(0, cleanTitle.length - 1);
        }

        updateConversationTitle(conversation, cleanTitle);
        appLogger.info(
          '[StreamingChat] Auto-renamed conversation to: $cleanTitle',
        );
      }
    } catch (e) {
      appLogger.error(
        '[StreamingChat] Failed to auto-rename conversation',
        error: e,
      );
    }
  }

  /// Get the appropriate streaming service
  StreamingService? _getStreamingService() {
    // Use connection manager to get the best streaming service
    return _connectionManager.getStreamingService();
  }

  /// Fallback to non-streaming chat when streaming is not available
  Future<void> _fallbackToNonStreamingChat(String content) async {
    try {
      appLogger.debug('[StreamingChat] Using fallback non-streaming chat');

      // Add loading message for assistant
      final fallbackModel = _selectedModel ?? 'default';
      final loadingMessage = Message.loading(model: fallbackModel);
      _addMessageToCurrentConversation(loadingMessage);

      // Get conversation history for context
      final history = _buildMessageHistory();

      // Use connection manager for fallback chat
      final response = await _connectionManager.sendChatMessage(
        model: fallbackModel,
        message: content,
        history: history,
      );

      // Remove loading message
      _removeLastMessage();

      if (response != null) {
        final assistantMessage = Message.assistant(
          content: response,
          model: fallbackModel,
        );
        _addMessageToCurrentConversation(assistantMessage);
        appLogger.debug('[StreamingChat] Fallback chat completed successfully');

        // Auto-rename conversation if it's the first message
        await _autoRenameConversation();
      } else {
        final errorMessage = Message.assistant(
          content:
              'Sorry, I encountered an error while processing your request.',
          model: fallbackModel,
          status: MessageStatus.error,
          error: 'Connection error',
        );
        _addMessageToCurrentConversation(errorMessage);
      }
    } catch (e) {
      appLogger.error('[StreamingChat] Fallback chat error', error: e);

      // Remove loading message if it exists
      if (_currentConversation != null &&
          _currentConversation!.messages.isNotEmpty) {
        final lastMessage = _currentConversation!.messages.last;
        if (lastMessage.isLoading) {
          _removeLastMessage();
        }
      }

      final fallbackModel = _selectedModel ?? 'default';
      final errorMessage = Message.assistant(
        content: 'Sorry, I encountered an error: ${e.toString()}',
        model: fallbackModel,
        status: MessageStatus.error,
        error: e.toString(),
      );
      _addMessageToCurrentConversation(errorMessage);
    }
  }

  /// Cancel current streaming
  void _cancelCurrentStream() {
    _currentStreamSubscription?.cancel();
    _currentStreamSubscription = null;
    _setStreaming(false);
    _streamingContentSubject.add('');
    _streamingReasoningSubject.add('');
  }

  /// Add message to current conversation
  void _addMessageToCurrentConversation(Message message) {
    try {
      if (_currentConversation == null) {
        appLogger.warning('Attempted to add message to null conversation');
        return;
      }

      final conversationId = _currentConversation!.id;
      final index = _conversations.indexWhere((c) => c.id == conversationId);

      if (index != -1) {
        final updatedConversation = _conversations[index].addMessage(message);
        _conversations[index] = updatedConversation;
        _currentConversation = updatedConversation;
        _saveConversations();
        notifyListeners();
      } else {
        appLogger.warning(
          'Current conversation not found in conversations list',
        );
      }
    } catch (e) {
      appLogger.error('Error adding message to conversation', error: e);
    }
  }

  /// Remove the last message from current conversation
  void _removeLastMessage() {
    try {
      if (_currentConversation == null ||
          _currentConversation!.messages.isEmpty) {
        return;
      }

      final conversationId = _currentConversation!.id;
      final index = _conversations.indexWhere((c) => c.id == conversationId);

      if (index != -1) {
        final updatedMessages =
            List<Message>.from(_conversations[index].messages);
        if (updatedMessages.isNotEmpty) {
          updatedMessages.removeLast();

          final updatedConversation = _conversations[index].copyWith(
            messages: updatedMessages,
            updatedAt: DateTime.now(),
          );

          _conversations[index] = updatedConversation;
          _currentConversation = updatedConversation;

          _saveConversations();
          notifyListeners();
        }
      }
    } catch (e) {
      appLogger.error('Error removing last message', error: e);
    }
  }

  /// Build message history for API
  List<Map<String, String>> _buildMessageHistory() {
    if (_currentConversation == null) return [];

    return _currentConversation!.messages
        .where(
          (m) =>
              m.role != MessageRole.system &&
              m.status == MessageStatus.sent &&
              !m.isStreaming,
        )
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set streaming state
  void _setStreaming(bool streaming) {
    _isStreaming = streaming;
    notifyListeners();
  }

  /// Clear all conversations
  void clearAllConversations() {
    _cancelCurrentStream();
    _conversations.clear();
    _currentConversation = null;

    // Clear from storage asynchronously
    _storageService.clearAllConversations().catchError((e) {
      appLogger.error(
        '[StreamingChat] Error clearing conversations from storage',
        error: e,
      );
    });

    notifyListeners();
  }

  @override
  void dispose() {
    appLogger.debug('[StreamingChat] Disposing service');

    _cancelCurrentStream();
    _streamingContentSubject.close();
    _streamingReasoningSubject.close();
    _connectionManager.removeListener(_onConnectionManagerChanged);
    _storageService.dispose();

    super.dispose();
  }
}
