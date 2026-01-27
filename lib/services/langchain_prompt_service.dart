/// Advanced prompt management service using LangChain templates
///
/// Provides sophisticated prompt templates, variable substitution,
/// and context-aware prompt generation for enhanced LLM interactions.
library;

import 'package:flutter/foundation.dart';
import 'package:langchain/langchain.dart';

import '../models/prompt_template_model.dart';

/// Prompt template categories
enum PromptCategory {
  conversation,
  codeGeneration,
  analysis,
  creative,
  technical,
  educational,
  custom,
}

/// Advanced prompt management service
class LangChainPromptService extends ChangeNotifier {
  // Built-in prompt templates
  final Map<String, ChatPromptTemplate> _builtInTemplates = {};
  final Map<String, ChatPromptTemplate> _customTemplates = {};
  final Map<String, PromptTemplateModel> _templateMetadata = {};

  // Current template state
  String? _activeTemplateId;
  Map<String, dynamic> _templateVariables = {};

  LangChainPromptService() {
    _initializeBuiltInTemplates();
  }

  // Getters
  String? get activeTemplateId => _activeTemplateId;
  Map<String, dynamic> get templateVariables => Map.from(_templateVariables);
  List<String> get availableTemplateIds => [
        ..._builtInTemplates.keys,
        ..._customTemplates.keys,
      ];

  /// Initialize built-in prompt templates
  void _initializeBuiltInTemplates() {
    // Conversation template
    _builtInTemplates['conversation'] = ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        'You are a helpful AI assistant. {personality}',
      ),
      const MessagesPlaceholder(variableName: 'history'),
      HumanChatMessagePromptTemplate.fromTemplate('{input}'),
    ]);

    _templateMetadata['conversation'] = PromptTemplateModel(
      id: 'conversation',
      name: 'General Conversation',
      description:
          'Standard conversational template with personality customization',
      category: PromptCategory.conversation,
      variables: ['personality', 'input'],
      isBuiltIn: true,
    );

    // Code generation template
    _builtInTemplates['code_generation'] =
        ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        '''You are an expert software developer. Generate clean, efficient, and well-documented code.

Programming Language: {language}
Code Style: {style}
Requirements: {requirements}

Guidelines:
- Write clean, readable code
- Include appropriate comments
- Follow best practices for {language}
- Ensure code is production-ready
- Add error handling where appropriate''',
      ),
      HumanChatMessagePromptTemplate.fromTemplate('{task}'),
    ]);

    _templateMetadata['code_generation'] = PromptTemplateModel(
      id: 'code_generation',
      name: 'Code Generation',
      description:
          'Template for generating code in various programming languages',
      category: PromptCategory.codeGeneration,
      variables: ['language', 'style', 'requirements', 'task'],
      isBuiltIn: true,
    );

    // Analysis template
    _builtInTemplates['analysis'] = ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        '''You are an expert analyst. Provide thorough, objective analysis based on the given data.

Analysis Type: {analysis_type}
Focus Areas: {focus_areas}
Output Format: {output_format}

Guidelines:
- Be objective and data-driven
- Provide clear insights and conclusions
- Support findings with evidence
- Identify patterns and trends
- Suggest actionable recommendations''',
      ),
      HumanChatMessagePromptTemplate.fromTemplate(
        'Data to analyze:\n{data}\n\nSpecific question: {question}',
      ),
    ]);

    _templateMetadata['analysis'] = PromptTemplateModel(
      id: 'analysis',
      name: 'Data Analysis',
      description: 'Template for analyzing data and providing insights',
      category: PromptCategory.analysis,
      variables: [
        'analysis_type',
        'focus_areas',
        'output_format',
        'data',
        'question',
      ],
      isBuiltIn: true,
    );

    // Creative writing template
    _builtInTemplates['creative'] = ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        '''You are a creative writer with expertise in {genre}. Create engaging, original content.

Writing Style: {style}
Target Audience: {audience}
Tone: {tone}
Length: {length}

Guidelines:
- Be creative and original
- Maintain consistent tone and style
- Engage the target audience
- Use vivid descriptions and compelling narratives
- Ensure proper structure and flow''',
      ),
      HumanChatMessagePromptTemplate.fromTemplate('{prompt}'),
    ]);

    _templateMetadata['creative'] = PromptTemplateModel(
      id: 'creative',
      name: 'Creative Writing',
      description: 'Template for creative writing tasks',
      category: PromptCategory.creative,
      variables: ['genre', 'style', 'audience', 'tone', 'length', 'prompt'],
      isBuiltIn: true,
    );

    // Technical documentation template
    _builtInTemplates['technical_docs'] =
        ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        '''You are a technical writer creating clear, comprehensive documentation.

Documentation Type: {doc_type}
Target Audience: {audience}
Technical Level: {technical_level}
Format: {format}

Guidelines:
- Use clear, concise language
- Include practical examples
- Structure information logically
- Add relevant code snippets or diagrams
- Ensure accuracy and completeness''',
      ),
      HumanChatMessagePromptTemplate.fromTemplate('{topic}'),
    ]);

    _templateMetadata['technical_docs'] = PromptTemplateModel(
      id: 'technical_docs',
      name: 'Technical Documentation',
      description: 'Template for creating technical documentation',
      category: PromptCategory.technical,
      variables: ['doc_type', 'audience', 'technical_level', 'format', 'topic'],
      isBuiltIn: true,
    );

    // Educational template
    _builtInTemplates['educational'] = ChatPromptTemplate.fromPromptMessages([
      SystemChatMessagePromptTemplate.fromTemplate(
        '''You are an expert educator teaching {subject} to {student_level} students.

Learning Objectives: {objectives}
Teaching Style: {teaching_style}
Duration: {duration}

Guidelines:
- Adapt content to student level
- Use clear explanations and examples
- Include interactive elements
- Check for understanding
- Provide practical applications
- Encourage critical thinking''',
      ),
      HumanChatMessagePromptTemplate.fromTemplate('{lesson_content}'),
    ]);

    _templateMetadata['educational'] = PromptTemplateModel(
      id: 'educational',
      name: 'Educational Content',
      description: 'Template for creating educational content and lessons',
      category: PromptCategory.educational,
      variables: [
        'subject',
        'student_level',
        'objectives',
        'teaching_style',
        'duration',
        'lesson_content',
      ],
      isBuiltIn: true,
    );

    debugPrint(
        '[LangChainPrompt] Built-in prompt templates initialized: ${_builtInTemplates.length}');
  }

  /// Get prompt template by ID
  ChatPromptTemplate? getTemplate(String templateId) {
    return _builtInTemplates[templateId] ?? _customTemplates[templateId];
  }

  /// Get template metadata
  PromptTemplateModel? getTemplateMetadata(String templateId) {
    return _templateMetadata[templateId];
  }

  /// Get templates by category
  List<PromptTemplateModel> getTemplatesByCategory(PromptCategory category) {
    return _templateMetadata.values
        .where((template) => template.category == category)
        .toList();
  }

  /// Set active template
  void setActiveTemplate(String templateId, {Map<String, dynamic>? variables}) {
    if (!_builtInTemplates.containsKey(templateId) &&
        !_customTemplates.containsKey(templateId)) {
      throw ArgumentError('Template not found: $templateId');
    }

    _activeTemplateId = templateId;
    _templateVariables = variables ?? {};

    debugPrint(
        '[LangChainPrompt] Active template set: $templateId (${_templateVariables.length} variables)');

    notifyListeners();
  }

  /// Update template variables
  void updateTemplateVariables(Map<String, dynamic> variables) {
    _templateVariables.addAll(variables);
    notifyListeners();
  }

  /// Set specific template variable
  void setTemplateVariable(String key, dynamic value) {
    _templateVariables[key] = value;
    notifyListeners();
  }

  /// Create custom template
  void createCustomTemplate({
    required String id,
    required String name,
    required String description,
    required PromptCategory category,
    required List<ChatMessagePromptTemplate> messages,
    required List<String> variables,
  }) {
    if (_builtInTemplates.containsKey(id) || _customTemplates.containsKey(id)) {
      throw ArgumentError('Template ID already exists: $id');
    }

    final template = ChatPromptTemplate.fromPromptMessages(messages);
    _customTemplates[id] = template;

    _templateMetadata[id] = PromptTemplateModel(
      id: id,
      name: name,
      description: description,
      category: category,
      variables: variables,
      isBuiltIn: false,
    );

    debugPrint(
        '[LangChainPrompt] Custom template created: $id ($name, ${category.name})');

    notifyListeners();
  }

  /// Delete custom template
  void deleteCustomTemplate(String templateId) {
    if (_builtInTemplates.containsKey(templateId)) {
      throw ArgumentError('Cannot delete built-in template: $templateId');
    }

    _customTemplates.remove(templateId);
    _templateMetadata.remove(templateId);

    if (_activeTemplateId == templateId) {
      _activeTemplateId = null;
      _templateVariables.clear();
    }

    debugPrint('[LangChainPrompt] Custom template deleted: $templateId');

    notifyListeners();
  }

  /// Format prompt with current template and variables
  Future<List<ChatMessage>> formatPrompt({
    String? templateId,
    Map<String, dynamic>? variables,
  }) async {
    final id = templateId ?? _activeTemplateId;
    if (id == null) {
      throw StateError('No active template set');
    }

    final template = getTemplate(id);
    if (template == null) {
      throw ArgumentError('Template not found: $id');
    }

    final vars = {..._templateVariables, ...?variables};

    try {
      final prompt = template.formatPrompt(vars);
      return prompt.toChatMessages();
    } catch (e) {
      debugPrint('[LangChainPrompt] Prompt format failed: $e (template: $id)');
      rethrow;
    }
  }

  /// Validate template variables
  bool validateTemplateVariables(
    String templateId,
    Map<String, dynamic> variables,
  ) {
    final metadata = getTemplateMetadata(templateId);
    if (metadata == null) return false;

    final requiredVars = metadata.variables;
    final providedVars = variables.keys.toSet();

    return requiredVars.every(providedVars.contains);
  }

  /// Get missing variables for a template
  List<String> getMissingVariables(
    String templateId,
    Map<String, dynamic> variables,
  ) {
    final metadata = getTemplateMetadata(templateId);
    if (metadata == null) return [];

    final requiredVars = metadata.variables.toSet();
    final providedVars = variables.keys.toSet();

    return requiredVars.difference(providedVars).toList();
  }

  /// Clear active template
  void clearActiveTemplate() {
    _activeTemplateId = null;
    _templateVariables.clear();
    notifyListeners();
  }
}
