/// RAG (Retrieval-Augmented Generation) service - stub version
///
/// Note: Ollama integration removed. RAG features disabled.
/// To re-enable, integrate with vLLM or another LLM backend.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

/// Document Q&A service using RAG (Retrieval-Augmented Generation)
/// Currently disabled - Ollama backend removed
class LangChainRAGService extends ChangeNotifier {
  // State management
  bool _isInitialized = false;
  final bool _isLoading = false;
  String? _error;
  int _documentCount = 0;

  LangChainRAGService();

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get documentCount => _documentCount;
  bool get hasDocuments => _documentCount > 0;

  /// Initialize the RAG service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('[LangChainRAG] RAG service disabled - Ollama backend removed');
    _error = 'RAG features disabled. Use GUI Automation instead.';
    _isInitialized = true;
    notifyListeners();
  }

  /// Load documents from a directory
  Future<void> loadDocumentsFromDirectory(String directoryPath) async {
    debugPrint('[LangChainRAG] loadDocumentsFromDirectory disabled');
    _error = 'RAG features disabled. Use GUI Automation instead.';
    notifyListeners();
  }

  /// Clear all loaded documents
  void clearDocuments() {
    _documentCount = 0;
    notifyListeners();
  }

  /// Query loaded documents
  Future<String?> queryDocuments(String query) async {
    debugPrint('[LangChainRAG] queryDocuments disabled');
    return 'RAG features disabled. Use GUI Automation instead.';
  }

  /// Get relevant chunks for a query
  Future<List<String>> getRelevantChunks(
    String query, {
    int numChunks = 3,
  }) async {
    return [];
  }

  /// Dispose resources
  @override
  void dispose() {
    super.dispose();
  }
}
