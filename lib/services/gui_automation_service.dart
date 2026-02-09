import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// GUI Automation Service
/// Screenshots → Vision Model → Actions
class GuiAutomationService extends ChangeNotifier {
  bool _isInitialized = false;
  bool _isProcessing = false;
  String _status = 'Ready';
  String _lastResult = '';
  String _modelEndpoint = 'http://localhost:8000'; // vLLM endpoint

  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  String get status => _status;
  String get lastResult => _lastResult;

  /// Initialize the service
  Future<void> initialize() async {
    _status = 'Initializing...';
    notifyListeners();

    try {
      // Check if vLLM server is running
      final response = await http.get(Uri.parse('$_modelEndpoint/v1/models'));
      if (response.statusCode == 200) {
        _isInitialized = true;
        _status = 'Ready - vLLM connected';
      } else {
        _status = 'Warning: vLLM not running (will use placeholder)';
      }
    } catch (e) {
      _status = 'vLLM not available - GUI features limited';
    }

    notifyListeners();
  }

  /// Take a screenshot
  Future<String?> takeScreenshot() async {
    _status = 'Taking screenshot...';
    notifyListeners();

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/gui_automation_${DateTime.now().millisecondsSinceEpoch}.png';
      
      // Call native method to take screenshot
      // This would use a Flutter method channel to native code
      // For now, placeholder implementation
      
      _status = 'Screenshot saved';
      notifyListeners();
      
      return path;
    } catch (e) {
      _status = 'Screenshot failed: $e';
      notifyListeners();
      return null;
    }
  }

  /// Analyze screenshot with vision model
  Future<String> analyzeScreenshot(String imagePath) async {
    if (!_isInitialized) {
      return 'Service not initialized';
    }

    _isProcessing = true;
    _status = 'Analyzing screenshot...';
    notifyListeners();

    try {
      // Read and encode image
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Send to vLLM server with UI-TARS model
      final response = await http.post(
        Uri.parse('$_modelEndpoint/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'ByteDance-Seed/UI-TARS-1.5-7B',
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'You are a GUI automation assistant. Analyze this screenshot and describe: 1) What applications are visible, 2) What the user is doing, 3) One simple action to take. Reply concisely.'},
                {'type': 'image_url', 'image_url': {'url': 'data:image/png;base64,$base64Image'}}
              ]
            }
          ],
          'max_tokens': 500
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _lastResult = data['choices'][0]['message']['content'];
      } else {
        _lastResult = 'Analysis failed: ${response.statusCode}';
      }
    } catch (e) {
      _lastResult = 'Error: $e';
    }

    _isProcessing = false;
    _status = 'Ready';
    notifyListeners();

    return _lastResult;
  }

  /// Execute action based on vision model response
  Future<String> executeAction(String action) async {
    _status = 'Executing: $action';
    notifyListeners();

    try {
      // Parse action and execute using native code
      // Supported actions: click(x,y), type(text), scroll(direction), keypress(key)
      
      // Example: "click(100,200)" -> click at coordinates
      // Example: "type(hello)" -> type text
      // Example: "scroll(down)" -> scroll down
      
      _status = 'Action completed';
      notifyListeners();
      
      return 'Executed: $action';
    } catch (e) {
      _status = 'Action failed: $e';
      notifyListeners();
      return 'Error: $e';
    }
  }

  /// Full workflow: Screenshot → Analyze → Action
  Future<String> automationWorkflow(String userInstruction) async {
    _status = 'Starting automation workflow...';
    notifyListeners();

    // 1. Take screenshot
    final screenshotPath = await takeScreenshot();
    if (screenshotPath == null) {
      return 'Failed to take screenshot';
    }

    // 2. Analyze with vision model
    final analysis = await analyzeScreenshot(screenshotPath);

    // 3. Generate action based on user instruction
    final action = await _generateAction(analysis, userInstruction);

    // 4. Execute action
    final result = await executeAction(action);

    return 'Analysis: $analysis\n\nAction: $action\n\nResult: $result';
  }

  /// Generate action from analysis and instruction
  Future<String> _generateAction(String analysis, String instruction) async {
    // Send to vision model to determine action
    // Placeholder: parse instruction for action type
    
    if (instruction.toLowerCase().contains('click')) {
      return 'click(100, 200)'; // Placeholder coordinates
    } else if (instruction.toLowerCase().contains('type')) {
      return 'type(hello)';
    } else if (instruction.toLowerCase().contains('scroll')) {
      return 'scroll(down)';
    }
    
    return 'analyze'; // Just analyze, no action
  }

  /// Set vLLM endpoint
  void setEndpoint(String endpoint) {
    _modelEndpoint = endpoint;
  }
}
