import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';

/// OCR Engine Service
///
/// This service handles optical character recognition (OCR) functionality.
/// It extracts text from images including screenshots and camera frames.
class OcrEngineService {
  bool _isInitialized = false;
  String? _lastError;

  /// Indicates whether the service has been initialized
  bool get isInitialized => _isInitialized;

  /// The last error that occurred (null if no error)
  String? get lastError => _lastError;

  /// Initialize the OCR engine
  ///
  /// Sets up Tesseract OCR for text extraction.
  /// This method is idempotent - calling it multiple times has no effect.
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('[OCR] Already initialized, skipping');
      return;
    }

    debugPrint('[OCR] Initializing Tesseract OCR...');

    try {
      // Tesseract OCR is initialized on first use
      _isInitialized = true;
      _lastError = null;
      debugPrint('[OCR] Initialized successfully');
    } catch (e) {
      _lastError = 'Failed to initialize OCR: $e';
      debugPrint('[OCR] $_lastError');
      _isInitialized = false;
    }
  }

  /// Extract text from an image file
  ///
  /// [imagePath] is the path to the image file (PNG, JPG, etc.)
  /// Returns the extracted text as a trimmed string, or empty string on failure.
  ///
  /// Throws [ArgumentError] if the image file doesn't exist.
  Future<String> extractText(String imagePath) async {
    if (!File(imagePath).existsSync()) {
      final error = 'Image file not found: $imagePath';
      _lastError = error;
      debugPrint('[OCR] $error');
      throw ArgumentError(error);
    }

    debugPrint('[OCR] Extracting text from: $imagePath');

    try {
      final config = OCRConfig(language: 'eng');
      final text = await TesseractOcr.extractText(imagePath, config: config);
      final result = text.trim();
      debugPrint('[OCR] Extracted ${result.length} characters');
      _lastError = null;
      return result;
    } catch (e) {
      _lastError = 'OCR extraction failed: $e';
      debugPrint('[OCR] $_lastError');
      return '';
    }
  }

  /// Extract text with multiple languages
  ///
  /// [imagePath] is the path to the image file
  /// [languages] is the list of languages to use (default: ['eng', 'chi_sim'])
  /// Returns the extracted text as a trimmed string, or empty string on failure.
  ///
  /// Throws [ArgumentError] if the image file doesn't exist.
  ///
  /// Language codes follow ISO 639-3 standard:
  /// - 'eng' for English
  /// - 'chi_sim' for Simplified Chinese
  /// - 'fra' for French
  /// - 'deu' for German
  /// - 'spa' for Spanish
  /// - etc.
  Future<String> extractTextMultilingual(
    String imagePath, {
    List<String> languages = const ['eng', 'chi_sim'],
  }) async {
    if (!File(imagePath).existsSync()) {
      final error = 'Image file not found: $imagePath';
      _lastError = error;
      debugPrint('[OCR] $error');
      throw ArgumentError(error);
    }

    final langString = languages.join('+');
    debugPrint('[OCR] Extracting text with languages: $langString');

    try {
      final config = OCRConfig(language: langString);
      final text = await TesseractOcr.extractText(imagePath, config: config);
      final result = text.trim();
      debugPrint('[OCR] Extracted ${result.length} characters');
      _lastError = null;
      return result;
    } catch (e) {
      _lastError = 'Multilingual OCR extraction failed: $e';
      debugPrint('[OCR] $_lastError');
      return '';
    }
  }

  /// Dispose of the OCR engine
  ///
  /// Releases OCR resources and resets state.
  Future<void> dispose() async {
    if (!_isInitialized) {
      return;
    }

    debugPrint('[OCR] Disposing...');

    _isInitialized = false;
    _lastError = null;

    debugPrint('[OCR] Disposed successfully');
  }
}
