import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/di/locator.dart' as di;
import 'package:cloudtolocalllm/services/vision/vision_service.dart';
import 'package:cloudtolocalllm/services/vision/region_capture_service.dart';
import 'package:cloudtolocalllm/services/vision/camera_capture_service.dart';
import 'package:cloudtolocalllm/services/vision/ocr_engine_service.dart';

/// Vision Settings Screen
/// Provides UI for configuring and testing vision system services
class VisionSettingsScreen extends StatefulWidget {
  const VisionSettingsScreen({super.key});

  @override
  State<VisionSettingsScreen> createState() => _VisionSettingsScreenState();
}

class _VisionSettingsScreenState extends State<VisionSettingsScreen> {
  bool _isInitializing = false;
  String _statusMessage = '';
  final List<String> _testResults = [];

  // Get services from DI
  late final MainVisionService _mainVisionService =
      di.serviceLocator<MainVisionService>();
  late final RegionCaptureService _regionCaptureService =
      di.serviceLocator<RegionCaptureService>();
  late final CameraCaptureService _cameraCaptureService =
      di.serviceLocator<CameraCaptureService>();
  late final OcrEngineService _ocrEngineService =
      di.serviceLocator<OcrEngineService>();

  Future<void> _initializeAllServices() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = 'Initializing services...';
    });

    try {
      // Initialize Main Vision Service
      try {
        await _mainVisionService.initialize();
        _testResults.add('✅ Main Vision Service initialized');
      } catch (e) {
        _testResults.add('❌ Main Vision Service: $e');
      }

      // Initialize Region Capture Service
      try {
        await _regionCaptureService.initialize();
        _testResults.add('✅ Region Capture Service initialized');
      } catch (e) {
        _testResults.add('❌ Region Capture Service: $e');
      }

      // Initialize Camera Capture Service
      try {
        await _cameraCaptureService.initialize();
        _testResults.add('✅ Camera Capture Service initialized');
      } catch (e) {
        _testResults.add('❌ Camera Capture Service: $e');
      }

      // Initialize OCR Engine Service
      try {
        await _ocrEngineService.initialize();
        _testResults.add('✅ OCR Engine Service initialized');
      } catch (e) {
        _testResults.add('❌ OCR Engine Service: $e');
      }

      setState(() {
        _statusMessage = 'Initialization complete';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
        _testResults.add('❌ Fatal error: $e');
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Widget _buildServiceStatusCard({
    required String title,
    required String icon,
    required bool isInitialized,
    String? lastError,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInitialized
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          child: Text(icon),
        ),
        title: Text(title),
        subtitle: Text(
          isInitialized ? 'Initialized' : (lastError ?? 'Not initialized'),
          style: TextStyle(
            color: isInitialized
                ? Theme.of(context).colorScheme.onPrimaryContainer
                : Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        trailing: Icon(
          isInitialized ? Icons.check_circle : Icons.error,
          color: isInitialized ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vision Settings'),
      ),
      body: Column(
        children: [
          // Service Status Cards
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Service Status',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _buildServiceStatusCard(
                  title: 'Main Vision Service',
                  icon: '👁️',
                  isInitialized: _mainVisionService.isInitialized,
                  lastError: null,
                ),
                _buildServiceStatusCard(
                  title: 'Region Capture Service',
                  icon: '🖼️',
                  isInitialized: _regionCaptureService.isInitialized,
                  lastError: _regionCaptureService.lastError,
                ),
                _buildServiceStatusCard(
                  title: 'Camera Capture Service',
                  icon: '📷',
                  isInitialized: _cameraCaptureService.isInitialized,
                  lastError: _cameraCaptureService.lastError,
                ),
                _buildServiceStatusCard(
                  title: 'OCR Engine Service',
                  icon: '🔤',
                  isInitialized: _ocrEngineService.isInitialized,
                  lastError: _ocrEngineService.lastError,
                ),
                if (_testResults.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Test Results',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _testResults
                              .map((result) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(result),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Bottom Action Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ElevatedButton(
                  onPressed: _isInitializing ? null : _initializeAllServices,
                  child: _isInitializing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Initialize All Services'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Services are managed by DI, don't dispose here
    super.dispose();
  }
}
