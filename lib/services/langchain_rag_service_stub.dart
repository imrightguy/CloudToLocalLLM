/// LangChain RAG service stub - for web platform
library;

import 'package:flutter/foundation.dart';

/// Document Q&A service stub (web platform only)
class LangChainRAGService extends ChangeNotifier {
  LangChainRAGService();

  bool get isInitialized => false;
  bool get isLoading => false;
  String? get error => 'RAG not available on this platform';
  int get documentCount => 0;
  bool get hasDocuments => false;

  Future<void> initialize() async {}
  Future<void> loadDocumentsFromDirectory(String directoryPath) async {}
  void clearDocuments() {}
  Future<String?> queryDocuments(String query) async => null;
  Future<List<String>> getRelevantChunks(String query,
          {int numChunks = 3}) async =>
      [];
}
