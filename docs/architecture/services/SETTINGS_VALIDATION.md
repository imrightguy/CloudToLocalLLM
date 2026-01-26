# Settings Validation and Error Handling

This document describes the validation and error handling system for the Platform Settings Screen.

## Overview

The settings validation and error handling system provides:

1. **SettingsValidator** - Validates all setting types with detailed error messages
2. **SettingsError** - Typed error representation with retry capability
3. **SettingsErrorHandler** - User-friendly error display and messaging
4. **SettingsState** - State management for validation errors and operation status
5. **Error Display Widgets** - Reusable UI components for showing errors
6. **Form Helper Widgets** - Validated input widgets with inline error display

## Components

### SettingsValidator

Located in `lib/services/settings_validator.dart`

Provides static validation methods for all setting types:

```dart
// Validate individual settings
ValidationResult validateTheme(String? theme);
ValidationResult validateLanguage(String? language);
ValidationResult validateProviderHost(String? host);
ValidationResult validateProviderPort(dynamic port);
ValidationResult validateProviderApiKey(String? apiKey);
ValidationResult validateProviderConfiguration({...});
ValidationResult validateWindowPosition(double? x, double? y);
ValidationResult validateWindowSize(double? width, double? height);
ValidationResult validateSettingsJson(Map<String, dynamic> json);

// Validate all settings together
ValidationResult validateAllSettings({...});
```

**ValidationResult** contains:

- `isValid` - Whether validation passed
- `errors` - Map of field names to error messages
- `overallError` - Overall error message (if any)

### SettingsError

Located in `lib/utils/settings_error_handler.dart`

Represents a settings error with type and context:

```dart
enum SettingsErrorType {
  validation,
  saveFailed,
  loadFailed,
  connectionFailed,
  importExportFailed,
  storageUnavailable,
  unknown,
}

class SettingsError {
  final SettingsErrorType type;
  final String message;
  final Map<String, String>? fieldErrors;
  final bool isRetryable;
  final Exception? originalException;
}
```

Factory constructors for common error types:

```dart
SettingsError.validation(message, fieldErrors);
SettingsError.saveFailed(message, originalException);
SettingsError.loadFailed(message, originalException);
SettingsError.connectionFailed(message, originalException);
SettingsError.importExportFailed(message, originalException);
SettingsError.storageUnavailable(message, originalException);
SettingsError.unknown(message, originalException);
```

### SettingsErrorHandler

Located in `lib/utils/settings_error_handler.dart`

Provides user-friendly error display:

```dart
// Get user-friendly message
String getUserMessage(SettingsError error);

// Get error icon
IconData getErrorIcon(SettingsError error);

// Get error color
Color getErrorColor(SettingsError error);

// Show error snackbar
void showErrorSnackbar(BuildContext context, SettingsError error, {VoidCallback? onRetry});

// Show error dialog
Future<void> showErrorDialog(BuildContext context, SettingsError error, {VoidCallback? onRetry});

// Show success message
void showSuccessMessage(BuildContext context, String message, {Duration duration});
```

### SettingsState

Located in `lib/models/settings_state.dart`

Manages validation and operation state:

```dart
enum SettingsOperationState {
  idle,
  loading,
  saving,
  success,
  error,
}

class SettingsState extends ChangeNotifier {
  // State getters
  SettingsOperationState get operationState;
  SettingsError? get error;
  Map<String, String> get fieldErrors;
  bool get isDirty;
  bool get isLoading;
  bool get isSaving;
  bool get hasError;
  bool get hasFieldErrors;

  // State setters
  void setLoading();
  void setSaving();
  void setSuccess();
  void setError(SettingsError error);
  void setFieldErrors(Map<String, String> errors);
  void clearFieldError(String fieldName);
  void clearErrors();
  void markDirty();
  void markClean();
  void reset();

  // Retry management
  void incrementRetryCount();
  void resetRetryCount();
  bool isMaxRetriesExceeded();
}
```

### Error Display Widgets

Located in `lib/widgets/settings/settings_error_widgets.dart`

**FieldErrorMessage** - Inline error for form fields

```dart
FieldErrorMessage(
  errorMessage: 'Invalid value',
  show: true,
)
```

**ErrorNotificationBanner** - General error notification

```dart
ErrorNotificationBanner(
  error: settingsError,
  onRetry: () { /* retry logic */ },
  onClose: () { /* close logic */ },
)
```

**SuccessNotificationBanner** - Success notification with auto-dismiss

```dart
SuccessNotificationBanner(
  message: 'Settings saved successfully',
  duration: Duration(seconds: 2),
  onDismissed: () { /* cleanup */ },
)
```

**ValidationErrorList** - List of validation errors

```dart
ValidationErrorList(
  errors: {'field1': 'error1', 'field2': 'error2'},
  onFieldTapped: (fieldName) { /* scroll to field */ },
)
```

**SettingsLoadingIndicator** - Loading state indicator

```dart
SettingsLoadingIndicator(message: 'Loading settings...')
```

**RetryButton** - Retry button with loading state

```dart
RetryButton(
  onRetry: () { /* retry */ },
  isLoading: false,
  label: 'Retry',
)
```

### Form Helper Widgets

Located in `lib/widgets/settings/settings_form_helper.dart`

**ValidatedSettingsTextField** - Text input with validation

```dart
ValidatedSettingsTextField(
  label: 'Host',
  fieldName: 'host',
  initialValue: 'localhost',
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
  onChanged: (value) { /* handle change */ },
  settingsState: settingsState,
  required: true,
)
```

**ValidatedSettingsDropdown** - Dropdown with validation

```dart
ValidatedSettingsDropdown<String>(
  label: 'Theme',
  fieldName: 'theme',
  items: ['light', 'dark', 'system'],
  itemLabel: (item) => item.toUpperCase(),
  initialValue: 'light',
  onChanged: (value) { /* handle change */ },
  settingsState: settingsState,
)
```

**ValidatedSettingsSwitch** - Toggle switch

```dart
ValidatedSettingsSwitch(
  label: 'Enable Analytics',
  fieldName: 'analytics',
  initialValue: true,
  onChanged: (value) { /* handle change */ },
  settingsState: settingsState,
)
```

**SettingsFormValidator** - Form validation helper

```dart
// Validate entire form
ValidationResult result = SettingsFormValidator.validateForm(
  values: {'theme': 'light', 'port': 11434},
  validators: {
    'theme': SettingsFormValidator.required('Theme'),
    'port': SettingsFormValidator.combine([
      SettingsFormValidator.required('Port'),
      (value) => validatePort(value),
    ]),
  },
);

// Create validators
SettingsFormValidator.required('Field name');
SettingsFormValidator.minLength(5);
SettingsFormValidator.maxLength(100);
SettingsFormValidator.pattern(RegExp(r'^\d+$'), 'Must be numeric');
SettingsFormValidator.combine([validator1, validator2]);
```

## Usage Examples

### Basic Validation

```dart
// Validate a single setting
final result = SettingsValidator.validateTheme('light');
if (!result.isValid) {
  print('Error: ${result.errors['theme']}');
}

// Validate provider configuration
final result = SettingsValidator.validateProviderConfiguration(
  host: 'http://localhost:11434',
  port: 11434,
  apiKey: null,
);
```

### Form with Validation

```dart
class MySettingsForm extends StatefulWidget {
  @override
  State<MySettingsForm> createState() => _MySettingsFormState();
}

class _MySettingsFormState extends State<MySettingsForm> {
  final settingsState = SettingsState();
  String? theme;
  String? host;
  int? port;

  void _saveSettings() async {
    settingsState.setSaving();

    try {
      // Validate
      final result = SettingsValidator.validateProviderConfiguration(
        host: host,
        port: port,
      );

      if (!result.isValid) {
        settingsState.setFieldErrors(result.errors);
        return;
      }

      // Save
      await saveSettings(theme: theme, host: host, port: port);
      settingsState.setSuccess();

      if (mounted) {
        SettingsErrorHandler.showSuccessMessage(
          context,
          'Settings saved successfully',
        );
      }
    } catch (e) {
      settingsState.setError(
        SettingsError.saveFailed('Failed to save settings', originalException: e as Exception),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsState,
      builder: (context, _) {
        return Column(
          children: [
            if (settingsState.hasError)
              ErrorNotificationBanner(
                error: settingsState.error!,
                onRetry: _saveSettings,
              ),
            ValidatedSettingsTextField(
              label: 'Host',
              fieldName: 'host',
              initialValue: host,
              onChanged: (value) => setState(() => host = value),
              settingsState: settingsState,
            ),
            ValidatedSettingsTextField(
              label: 'Port',
              fieldName: 'port',
              initialValue: port?.toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => port = int.tryParse(value)),
              settingsState: settingsState,
            ),
            FilledButton(
              onPressed: settingsState.isSaving ? null : _saveSettings,
              child: settingsState.isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
```

### Error Handling with Retry

```dart
void _handleSettingsError(SettingsError error) {
  if (error.isRetryable) {
    SettingsErrorHandler.showErrorSnackbar(
      context,
      error,
      onRetry: () {
        settingsState.incrementRetryCount();
        if (!settingsState.isMaxRetriesExceeded()) {
          _saveSettings();
        } else {
          SettingsErrorHandler.showErrorDialog(
            context,
            SettingsError.error('Max retries exceeded. Please try again later.'),
          );
        }
      },
    );
  } else {
    SettingsErrorHandler.showErrorDialog(context, error);
  }
}
```

## Validation Rules

### Theme

- Required
- Must be one of: 'light', 'dark', 'system'

### Language

- Required
- Must be one of: 'en', 'es', 'fr', 'de', 'ja', 'zh'

### Provider Host

- Required
- Must be valid URL format

### Provider Port

- Required
- Must be integer between 1 and 65535

### Provider API Key

- Optional
- If provided, cannot be empty

### Window Position

- Both X and Y must be non-negative
- Cannot be null if validating position

### Window Size

- Width and height must be at least 400x300 pixels
- Width and height cannot exceed 7680x4320 pixels

### Settings JSON

- Cannot be empty
- All values must be serializable (string, number, boolean, null, list, map)

## Error Types and Retry Behavior

| Error Type | Retryable | User Message |
|---|---|---|
| Validation | No | Field-specific error messages |
| Save Failed | Yes | "Failed to save settings. Please try again." |
| Load Failed | Yes | "Failed to load settings. Please try again." |
| Connection Failed | Yes | "Connection failed. Please check your settings and try again." |
| Import/Export Failed | No | "Failed to import/export settings. [Details]" |
| Storage Unavailable | Yes | "Settings storage is unavailable. Your changes will not be saved." |
| Unknown | Yes | "An unexpected error occurred. Please try again." |

## Performance Considerations

- Validation is synchronous and completes within 200ms
- Field errors are displayed inline without blocking UI
- Error messages are cached to avoid repeated computation
- Retry logic includes exponential backoff (configurable)
- Maximum 3 retry attempts before showing final error

## Testing

Unit tests are provided in `test/services/settings_validator_test.dart`:

```bash
flutter test test/services/settings_validator_test.dart
```

Tests cover:

- All validation methods
- Valid and invalid inputs
- Edge cases (null, empty, boundary values)
- Multiple error scenarios
- ValidationResult creation and methods

## Integration with Settings Screen

The validation system integrates with the UnifiedSettingsScreen:

1. **Form Initialization** - Load current settings and validate
2. **User Input** - Validate on change with 300ms debounce
3. **Field Errors** - Display inline errors below fields
4. **Save Operation** - Validate all fields before saving
5. **Error Handling** - Show appropriate error messages
6. **Retry Logic** - Allow retry for transient errors
7. **Success Feedback** - Show success message for 2 seconds

## Future Enhancements

- Custom validation rules per setting type
- Async validation (e.g., connection testing)
- Validation rule composition
- Localized error messages
- Error analytics and reporting
- Validation performance metrics
