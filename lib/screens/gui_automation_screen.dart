import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/gui_automation_service.dart';

class GuiAutomationScreen extends StatefulWidget {
  const GuiAutomationScreen({super.key});

  @override
  State<GuiAutomationScreen> createState() => _GuiAutomationScreenState();
}

class _GuiAutomationScreenState extends State<GuiAutomationScreen> {
  final _service = GuiAutomationService();
  final _instructionController = TextEditingController();
  String _result = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _service.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GUI Automation'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _service.isInitialized
                              ? Icons.check_circle
                              : Icons.warning,
                          color: _service.isInitialized
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(_service.status),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Quick Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _takeScreenshot,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Screenshot'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _runAnalysis,
                          icon: const Icon(Icons.analytics),
                          label: const Text('Analyze'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Instruction Input
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What do you want to do?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _instructionController,
                      decoration: const InputDecoration(
                        hintText:
                            'e.g., Click the search button, Type in the box',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _runWorkflow,
                        child: const Text('Execute'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Results
            if (_result.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Result',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(_result),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Info Footer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'GUI Automation is powered by OpenClaw Gateway.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takeScreenshot() async {
    final path = await _service.takeScreenshot();
    if (path != null) {
      setState(() {
        _result = 'Screenshot saved: $path';
      });
    }
  }

  Future<void> _runAnalysis() async {
    setState(() => _isProcessing = true);
    final screenshotPath = await _service.takeScreenshot();
    if (screenshotPath != null) {
      final result = await _service.analyzeScreenshot(screenshotPath);
      setState(() => _result = result);
    }
    setState(() => _isProcessing = false);
  }

  Future<void> _runWorkflow() async {
    if (_instructionController.text.isEmpty) return;

    setState(() => _isProcessing = true);
    final result =
        await _service.automationWorkflow(_instructionController.text);
    setState(() {
      _result = result;
      _isProcessing = false;
    });
  }
}
