/// Stub for LangChain Prompt Service
/// This service is needed by the service locator but not yet implemented
library;

class LangChainPromptService {
  LangChainPromptService();

  /// Initialize prompt templates
  Future<void> initialize() async {
    // Stub - no-op
  }

  /// Get a prompt template by name
  String? getPromptTemplate(String name) {
    // Stub - returns null
    return null;
  }

  /// Render a prompt with variables
  String renderPrompt(String template, Map<String, dynamic> variables) {
    // Stub - returns empty string
    return '';
  }
}
