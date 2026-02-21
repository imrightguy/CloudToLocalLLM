/// Settings State Model
///
/// Manages the state of settings including validation errors and save status.
library;

import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

/// Settings operation state
enum SettingsOperationState {
  /// Idle, no operation in progress
  idle,

  /// Loading settings
  loading,

  /// Saving settings
  saving,

  /// Operation completed successfully
  success,

  /// Operation failed
  error,
}

/// Settings state model
class SettingsState extends ChangeNotifier {
  /// Current operation state
  SettingsOperationState _operationState = SettingsOperationState.idle;

  /// Current error (if any)
  SettingsError? _error;

  /// Field-level validation errors
  Map<String, String> _fieldErrors = {};

  /// Whether there are unsaved changes
  bool _isDirty = false;

  /// Last successful save timestamp
  DateTime? _lastSaveTime;

  /// Retry count for failed operations
  int _retryCount = 0;

  /// Maximum retry attempts
  static const int maxRetries = 3;

  // Getters
  SettingsOperationState get operationState => _operationState;
  SettingsError? get error => _error;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get isDirty => _isDirty;
  DateTime? get lastSaveTime => _lastSaveTime;
  int get retryCount => _retryCount;

  /// Whether the operation is in progress
  bool get isLoading => _operationState == SettingsOperationState.loading;

  /// Whether the operation is saving
  bool get isSaving => _operationState == SettingsOperationState.saving;

  /// Whether there are any errors
  bool get hasError => _error != null;

  /// Whether there are field-level errors
  bool get hasFieldErrors => _fieldErrors.isNotEmpty;

  /// Get error message for a specific field
  String? getFieldError(String fieldName) => _fieldErrors[fieldName];

  /// Set operation state to loading
  void setLoading() {
    _operationState = SettingsOperationState.loading;
    _error = null;
    _fieldErrors = {};
    notifyListeners();
  }

  /// Set operation state to saving
  void setSaving() {
    _operationState = SettingsOperationState.saving;
    _error = null;
    _fieldErrors = {};
    notifyListeners();
  }

  /// Set operation state to success
  void setSuccess() {
    _operationState = SettingsOperationState.success;
    _error = null;
    _fieldErrors = {};
    _isDirty = false;
    _lastSaveTime = DateTime.now();
    _retryCount = 0;
    notifyListeners();
  }

  /// Set operation state to error
  void setError(SettingsError error) {
    _operationState = SettingsOperationState.error;
    _error = error;

    // Extract field errors if present
    if (error.fieldErrors != null) {
      _fieldErrors = error.fieldErrors!;
    } else {
      _fieldErrors = {};
    }

    notifyListeners();
  }

  /// Set field-level validation errors
  void setFieldErrors(Map<String, String> errors) {
    _fieldErrors = errors;
    if (errors.isNotEmpty) {
      _operationState = SettingsOperationState.error;
      _error = SettingsError.validation(
        'Please fix the errors below',
        fieldErrors: errors,
      );
    } else {
      _error = null;
      _operationState = SettingsOperationState.idle;
    }
    notifyListeners();
  }

  /// Clear a specific field error
  void clearFieldError(String fieldName) {
    _fieldErrors.remove(fieldName);
    if (_fieldErrors.isEmpty) {
      _error = null;
      _operationState = SettingsOperationState.idle;
    }
    notifyListeners();
  }

  /// Clear all errors
  void clearErrors() {
    _error = null;
    _fieldErrors = {};
    _operationState = SettingsOperationState.idle;
    notifyListeners();
  }

  /// Mark settings as dirty (unsaved changes)
  void markDirty() {
    _isDirty = true;
    notifyListeners();
  }

  /// Mark settings as clean (no unsaved changes)
  void markClean() {
    _isDirty = false;
    notifyListeners();
  }

  /// Increment retry count
  void incrementRetryCount() {
    _retryCount++;
    notifyListeners();
  }

  /// Reset retry count
  void resetRetryCount() {
    _retryCount = 0;
    notifyListeners();
  }

  /// Check if max retries exceeded
  bool isMaxRetriesExceeded() => _retryCount >= maxRetries;

  /// Reset to idle state
  void reset() {
    _operationState = SettingsOperationState.idle;
    _error = null;
    _fieldErrors = {};
    _isDirty = false;
    _retryCount = 0;
    notifyListeners();
  }
}
