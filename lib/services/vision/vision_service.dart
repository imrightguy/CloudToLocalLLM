import 'package:flutter/foundation.dart';

/// Base vision service providing screen capture and OCR capabilities
///
/// This abstract class defines the contract for all vision services
/// in the CloudToLocalLLM application. Vision services enable the AI
/// assistant to see and understand visual content through screen capture,
/// region selection, camera input, and OCR text extraction.
abstract class VisionService {
  /// Indicates whether the service has been initialized
  bool get isInitialized;

  /// Indicates whether the service is currently capturing
  bool get isCapturing;

  /// Initialize the vision service
  ///
  /// This method sets up the service and prepares it for use.
  /// It should be called before any other methods.
  Future<void> initialize();

  /// Dispose of the vision service
  ///
  /// This method cleans up resources and should be called when
  /// the service is no longer needed.
  Future<void> dispose();
}

/// Main vision service coordinator
///
/// This service coordinates all vision-related operations including
/// screen capture, camera input, region selection, and OCR processing.
/// It implements the VisionService interface and provides change
/// notifications for UI updates.
class MainVisionService extends ChangeNotifier implements VisionService {
  bool _isInitialized = false;
  bool _isCapturing = false;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isCapturing => _isCapturing;

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[VisionService] Already initialized, skipping');
      return;
    }

    debugPrint('[VisionService] Initializing...');

    // Initialize vision service components
    // Future tasks will initialize:
    // - Region capture service
    // - Camera capture service
    // - OCR engine service

    _isInitialized = true;
    notifyListeners();

    debugPrint('[VisionService] Initialization complete');
  }

  @override
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[VisionService] Disposing...');

    _isInitialized = false;
    _isCapturing = false;

    // Dispose of vision service components
    // Future tasks will dispose:
    // - Region capture service
    // - Camera capture service
    // - OCR engine service

    super.dispose();

    debugPrint('[VisionService] Disposal complete');
  }
}
