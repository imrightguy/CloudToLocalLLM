import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Camera Capture Service
///
/// This service handles camera input capture for real-time vision.
/// It provides access to webcam feeds and frame capture capabilities.
class CameraCaptureService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _lastError;

  /// Indicates whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Indicates whether the service is currently capturing
  bool get isCapturing => _isCapturing;

  /// List of available cameras
  List<CameraDescription> get cameras => _cameras;

  /// The last error that occurred (null if no error)
  String? get lastError => _lastError;

  /// Initialize the camera capture service
  ///
  /// Gets available cameras and initializes the first camera with
  /// high resolution preset. Returns silently if already initialized.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[CameraCapture] Already initialized, skipping');
      return;
    }

    debugPrint('[CameraCapture] Initializing...');

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        _lastError = 'No cameras available on this device';
        debugPrint('[CameraCapture] $_lastError');
        return;
      }

      debugPrint('[CameraCapture] Found ${_cameras.length} camera(s)');

      _controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      _isInitialized = true;
      _lastError = null;

      debugPrint('[CameraCapture] Initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize camera: $e';
      debugPrint('[CameraCapture] $_lastError');
      _isInitialized = false;
    }
  }

  /// Capture an image from the camera
  ///
  /// Takes a picture and saves it to the temporary directory.
  /// Returns the file path if successful, null otherwise.
  ///
  /// Throws [StateError] if the camera is not initialized.
  Future<String?> captureImage() async {
    if (!_isInitialized || _controller == null) {
      final error = 'Camera not initialized. Call initialize() first.';
      _lastError = error;
      debugPrint('[CameraCapture] $error');
      throw StateError(error);
    }

    if (_isCapturing) {
      debugPrint('[CameraCapture] Already capturing, ignoring request');
      return null;
    }

    _isCapturing = true;
    _lastError = null;

    try {
      debugPrint('[CameraCapture] Capturing image...');

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${directory.path}/camera_$timestamp.png';

      final XFile image = await _controller!.takePicture();

      // Copy the image to our desired path
      await File(image.path).copy(path);

      debugPrint('[CameraCapture] Image saved to $path');
      return path;
    } catch (e) {
      _lastError = 'Failed to capture image: $e';
      debugPrint('[CameraCapture] $_lastError');
      return null;
    } finally {
      _isCapturing = false;
    }
  }

  /// Get the camera controller for preview widgets
  ///
  /// Returns null if the camera is not initialized.
  CameraController? get controller => _controller;

  /// Dispose of the camera capture service
  ///
  /// Releases the camera controller and cleans up resources.
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[CameraCapture] Disposing...');

    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isCapturing = false;
    _lastError = null;

    debugPrint('[CameraCapture] Disposed successfully');
  }

  /// Switch to a different camera
  ///
  /// [cameraIndex] - The index of the camera to switch to
  /// Throws [RangeError] if the index is out of bounds.
  /// Throws [StateError] if the camera is not initialized.
  Future<void> switchCamera(int cameraIndex) async {
    if (!_isInitialized) {
      throw StateError('Camera not initialized. Call initialize() first.');
    }

    if (cameraIndex < 0 || cameraIndex >= _cameras.length) {
      throw RangeError(
        'Camera index $cameraIndex out of range (0-${_cameras.length - 1})',
      );
    }

    debugPrint('[CameraCapture] Switching to camera $cameraIndex');

    await _controller?.dispose();

    _controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();
    debugPrint('[CameraCapture] Switched to camera $cameraIndex');
  }
}
