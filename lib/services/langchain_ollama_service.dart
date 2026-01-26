/// LangChain-powered Ollama service for CloudToLocalLLM
///
/// This service replaces the custom Ollama implementation with LangChain's
/// comprehensive framework, providing enhanced capabilities like memory,
/// chains, RAG, and structured output parsing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_ollama/langchain_ollama.dart';

import '../config/app_config.dart';
import '../models/message.dart';
import 'connection_manager_service.dart';

/// Enhanced Ollama service using LangChain framework
class LangChainOllamaService extends ChangeNotifier {
  final ConnectionManagerService _connectionManager;

  // LangChain components
  ChatOllama? _chatModel;
  ConversationBufferMemory? _memory;
  Runnable? _conversationChain;

  // State management
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  List<String> _availableModels = [];
  String? _currentModel;

  // Conversation management
  final Map<String, ConversationBufferMemory> _conversationMemories = {};
  final Map<String, List<Message>> _conversations = {};

  LangChainOllamaService({required ConnectionManagerService connectionManager})
      : _connectionManager = connectionManager;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  bool get hasActiveModel => _currentModel != null && _isInitialized;
  ChatOllama? get chatModel => _chatModel;

  /// Initialize the LangChain Ollama service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      debugPrint(
          '[langchain_ollama_service] Initializing LangChain Ollama service');

      // Wait for connection manager to be ready
      if (!_connectionManager.hasAnyConnection) {
        await _connectionManager.initialize();
      }

      if (!_connectionManager.hasAnyConnection) {
        _error =
            'No connection available. Connect a desktop bridge to use cloud models.';
        debugPrint(
            '[LangChainOllama] Initialization skipped: No connection available after connection manager init');
        _isInitialized = false;
        notifyListeners();
        return;
      }

      // Initialize with default model
      try {
        await _initializeChatModel('gemma2:2b');
      } on StateError catch (e) {
        _error =
            'No connection available. Connect a desktop bridge to use cloud models.';
        debugPrint('[LangChainOllama] Initialization skipped: $e');
        _isInitialized = false;
        notifyListeners();
        return;
      }

      // Load available models
      await _loadAvailableModels();

      _isInitialized = true;
      debugPrint(
          '[langchain_ollama_service] LangChain Ollama service initialized successfully');
    } catch (e) {
      _error = 'Failed to initialize LangChain service: $e';
      debugPrint('[LangChainOllama] Initialization failed: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize chat model with specified model name
  Future<void> _initializeChatModel(String modelName) async {
    try {
      // Create LangChain Ollama chat model
      // Route through existing tunnel infrastructure
      final baseUrl = _getOllamaBaseUrl();

      _chatModel = ChatOllama(
        baseUrl: baseUrl,
        defaultOptions: ChatOllamaOptions(model: modelName, temperature: 0.7),
      );

      _currentModel = modelName;

      // Initialize conversation memory
      _memory = ConversationBufferMemory(
        returnMessages: true,
        memoryKey: 'history',
      );

      // Create conversation chain with prompt template
      await _createConversationChain();

      debugPrint('[LangChainOllama] Chat model initialized: $modelName');
    } catch (e) {
      debugPrint('[LangChainOllama] Chat model init failed: $modelName - $e');
      rethrow;
    }
  }

  /// Create conversation chain with memory and prompt template
  Future<void> _createConversationChain() async {
    if (_chatModel == null || _memory == null) return;

    try {
      // Create prompt template for conversations
      final promptTemplate = ChatPromptTemplate.fromPromptMessages([
        SystemChatMessagePromptTemplate.fromTemplate(
          'You are a helpful AI assistant. Provide clear, accurate, and helpful responses.',
        ),
        const MessagesPlaceholder(variableName: 'history'),
        HumanChatMessagePromptTemplate.fromTemplate('{input}'),
      ]);

      // Create conversation chain with memory
      _conversationChain = Runnable.fromMap({
        'input': Runnable.passthrough(),
        'history': Runnable.mapInput((_) async {
          final memoryVars = await _memory!.loadMemoryVariables();
          return memoryVars['history'] ?? [];
        }),
      })
          .pipe(promptTemplate)
          .pipe(_chatModel!)
          .pipe(const StringOutputParser<ChatResult>());

      debugPrint(
          '[langchain_ollama_service] Conversation chain created successfully');
    } catch (e) {
      debugPrint('[LangChainOllama] Conversation chain failed: $e');
      rethrow;
    }
  }

  /// Get Ollama base URL based on connection type
  String _getOllamaBaseUrl() {
    // Use existing connection manager to determine the appropriate URL
    // langchain_ollama package expects the base URL to include /api in many cases
    // to correctly route to /api/generate or /api/chat.
    switch (_connectionManager.getBestConnectionType()) {
      case ConnectionType.local:
        return 'http://localhost:11434/api';
      case ConnectionType.cloud:
        // Route through tunnel system
        return '${AppConfig.cloudOllamaUrl}/api';
      case ConnectionType.none:
        throw StateError('No connection available');
    }
  }

  /// Load available models from Ollama
  Future<void> _loadAvailableModels() async {
    try {
      // Use connection manager to get available models
      final connectionManager = _connectionManager;
      if (connectionManager.hasAnyConnection) {
        final models = connectionManager.availableModels;
        if (models.isNotEmpty) {
          _availableModels = models;
        } else {
          // Fallback to default models if none available
          _availableModels = [
            'gemma2:2b',
            'gemma2:9b',
            'llama3.2',
            'llama3.1',
            'mistral',
            'neural-chat',
          ];
        }
      } else {
        // No connection available, use default models
        _availableModels = [
          'gemma2:2b',
          'gemma2:9b',
          'llama3.2',
          'llama3.1',
          'mistral',
          'neural-chat',
        ];
      }

      debugPrint(
          '[LangChainOllama] Available models loaded: ${_availableModels.length}');
    } catch (e) {
      debugPrint('[LangChainOllama] Models load failed: $e');
      // Don't rethrow - this is not critical for basic functionality
    }
  }

  /// Send a chat message with conversation memory
  Future<String> sendMessage({
    required String message,
    String? conversationId,
  }) async {
    if (!_isInitialized || _conversationChain == null) {
      throw StateError('LangChain service not initialized');
    }

    try {
      _setLoading(true);
      _clearError();

      final convId = conversationId ?? 'default';

      // Get or create conversation memory for this conversation
      final memory = _getConversationMemory(convId);

      debugPrint(
          '[LangChainOllama] Sending message: convId=$convId, length=${message.length}');

      // Invoke the conversation chain
      final response = await _conversationChain!.invoke({'input': message});
      final responseString = response.toString();

      // Save the conversation to memory
      await memory.saveContext(
        inputValues: {'input': message},
        outputValues: {'output': responseString},
      );

      // Update local conversation history
      _updateConversationHistory(convId, message, responseString);

      debugPrint(
          '[LangChainOllama] Message processed: convId=$convId, length=${responseString.length}');

      return responseString;
    } catch (e) {
      _error = 'Failed to send message: $e';
      debugPrint('[LangChainOllama] Message send failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Get conversation memory for a specific conversation
  ConversationBufferMemory _getConversationMemory(String conversationId) {
    return _conversationMemories.putIfAbsent(
      conversationId,
      () =>
          ConversationBufferMemory(returnMessages: true, memoryKey: 'history'),
    );
  }

  /// Update local conversation history
  void _updateConversationHistory(
    String conversationId,
    String input,
    String output,
  ) {
    final messages = _conversations.putIfAbsent(conversationId, () => []);

    messages.addAll([
      Message.user(
        content: input,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      ),
      Message.assistant(
        content: output,
        model: _currentModel ?? 'unknown',
        id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      ),
    ]);

    notifyListeners();
  }

  /// Get conversation history
  List<Message> getConversationHistory(String conversationId) {
    return _conversations[conversationId] ?? [];
  }

  /// Switch to a different model
  Future<void> switchModel(String modelName) async {
    if (_currentModel == modelName) return;

    try {
      _setLoading(true);
      _clearError();

      await _initializeChatModel(modelName);

      debugPrint(
          '[LangChainOllama] Model switched: $_currentModel -> $modelName');
    } catch (e) {
      _error = 'Failed to switch model: $e';
      debugPrint('[LangChainOllama] Model switch failed: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear conversation history
  void clearConversation(String conversationId) {
    _conversations.remove(conversationId);
    _conversationMemories.remove(conversationId);
    notifyListeners();
  }

  /// Clear all conversations
  void clearAllConversations() {
    _conversations.clear();
    _conversationMemories.clear();
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _conversations.clear();
    _conversationMemories.clear();
    super.dispose();
  }
}
