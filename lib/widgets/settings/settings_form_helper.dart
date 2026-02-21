/// Settings Form Helper
///
/// Provides helper utilities for building validated settings forms.
library;

import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/settings_validator.dart';
import 'package:cloudtolocalllm/models/settings_state.dart';

/// Validated text field for settings
class ValidatedSettingsTextField extends StatefulWidget {
  /// Field label
  final String label;

  /// Field description
  final String? description;

  /// Initial value
  final String? initialValue;

  /// Validation function
  final String? Function(String?)? validator;

  /// Callback when value changes
  final ValueChanged<String>? onChanged;

  /// Callback when field is submitted
  final ValueChanged<String>? onSubmitted;

  /// Settings state for error display
  final SettingsState? settingsState;

  /// Field name for error tracking
  final String fieldName;

  /// Whether the field is required
  final bool required;

  /// Input type
  final TextInputType keyboardType;

  /// Whether to obscure text
  final bool obscureText;

  /// Maximum lines
  final int? maxLines;

  /// Minimum lines
  final int? minLines;

  /// Helper text
  final String? helperText;

  const ValidatedSettingsTextField({
    super.key,
    required this.label,
    this.description,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.settingsState,
    required this.fieldName,
    this.required = false,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.helperText,
  });

  @override
  State<ValidatedSettingsTextField> createState() =>
      _ValidatedSettingsTextFieldState();
}

class _ValidatedSettingsTextFieldState
    extends State<ValidatedSettingsTextField> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate() {
    final error = widget.validator?.call(_controller.text);
    setState(() {
      _error = error;
    });

    if (error != null) {
      widget.settingsState?.setFieldErrors({widget.fieldName: error});
    } else {
      widget.settingsState?.clearFieldError(widget.fieldName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldError = widget.settingsState?.getFieldError(widget.fieldName);
    final hasError = _error != null || fieldError != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: widget.label,
              helperText: widget.helperText,
              errorText: _error ?? fieldError,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError ? Colors.red : Colors.blue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade600),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.red.shade600, width: 2),
              ),
              suffixIcon: hasError
                  ? Icon(Icons.error_outline, color: Colors.red.shade600)
                  : null,
            ),
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            onChanged: (value) {
              widget.onChanged?.call(value);
              _validate();
            },
            onSubmitted: widget.onSubmitted,
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Validated dropdown for settings
class ValidatedSettingsDropdown<T> extends StatefulWidget {
  /// Field label
  final String label;

  /// Field description
  final String? description;

  /// Initial value
  final T? initialValue;

  /// Available options
  final List<T> items;

  /// Function to get display label for item
  final String Function(T) itemLabel;

  /// Validation function
  final String? Function(T?)? validator;

  /// Callback when value changes
  final ValueChanged<T?>? onChanged;

  /// Settings state for error display
  final SettingsState? settingsState;

  /// Field name for error tracking
  final String fieldName;

  /// Whether the field is required
  final bool required;

  const ValidatedSettingsDropdown({
    super.key,
    required this.label,
    this.description,
    this.initialValue,
    required this.items,
    required this.itemLabel,
    this.validator,
    this.onChanged,
    this.settingsState,
    required this.fieldName,
    this.required = false,
  });

  @override
  State<ValidatedSettingsDropdown<T>> createState() =>
      _ValidatedSettingsDropdownState<T>();
}

class _ValidatedSettingsDropdownState<T>
    extends State<ValidatedSettingsDropdown<T>> {
  late T? _selectedValue;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
  }

  void _validate() {
    final error = widget.validator?.call(_selectedValue);
    setState(() {
      _error = error;
    });

    if (error != null) {
      widget.settingsState?.setFieldErrors({widget.fieldName: error});
    } else {
      widget.settingsState?.clearFieldError(widget.fieldName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldError = widget.settingsState?.getFieldError(widget.fieldName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownMenu<T>(
            initialSelection: _selectedValue,
            label: Text(widget.label),
            dropdownMenuEntries: widget.items
                .map(
                  (item) => DropdownMenuEntry(
                    value: item,
                    label: widget.itemLabel(item),
                  ),
                )
                .toList(),
            onSelected: (value) {
              setState(() {
                _selectedValue = value;
              });
              widget.onChanged?.call(value);
              _validate();
            },
            errorText: _error ?? fieldError,
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Validated switch for settings
class ValidatedSettingsSwitch extends StatefulWidget {
  /// Field label
  final String label;

  /// Field description
  final String? description;

  /// Initial value
  final bool initialValue;

  /// Callback when value changes
  final ValueChanged<bool>? onChanged;

  /// Settings state for error display
  final SettingsState? settingsState;

  /// Field name for error tracking
  final String fieldName;

  const ValidatedSettingsSwitch({
    super.key,
    required this.label,
    this.description,
    this.initialValue = false,
    this.onChanged,
    this.settingsState,
    required this.fieldName,
  });

  @override
  State<ValidatedSettingsSwitch> createState() =>
      _ValidatedSettingsSwitchState();
}

class _ValidatedSettingsSwitchState extends State<ValidatedSettingsSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: _value,
            onChanged: (value) {
              setState(() {
                _value = value;
              });
              widget.onChanged?.call(value);
            },
          ),
        ],
      ),
    );
  }
}

/// Form validation helper
class SettingsFormValidator {
  /// Validate all fields in a form
  static ValidationResult validateForm({
    required Map<String, dynamic> values,
    required Map<String, String? Function(dynamic)> validators,
  }) {
    final errors = <String, String>{};

    for (final entry in validators.entries) {
      final fieldName = entry.key;
      final validator = entry.value;
      final value = values[fieldName];

      final error = validator(value);
      if (error != null) {
        errors[fieldName] = error;
      }
    }

    if (errors.isNotEmpty) {
      return ValidationResult.fieldErrors(errors);
    }

    return ValidationResult.success();
  }

  /// Create a required field validator
  static String? Function(dynamic) required(String fieldName) {
    return (value) {
      if (value == null || (value is String && value.isEmpty)) {
        return '$fieldName is required';
      }
      return null;
    };
  }

  /// Create a min length validator
  static String? Function(dynamic) minLength(int length) {
    return (value) {
      if (value is String && value.length < length) {
        return 'Must be at least $length characters';
      }
      return null;
    };
  }

  /// Create a max length validator
  static String? Function(dynamic) maxLength(int length) {
    return (value) {
      if (value is String && value.length > length) {
        return 'Must be at most $length characters';
      }
      return null;
    };
  }

  /// Create a pattern validator
  static String? Function(dynamic) pattern(RegExp regex, String message) {
    return (value) {
      if (value is String && !regex.hasMatch(value)) {
        return message;
      }
      return null;
    };
  }

  /// Combine multiple validators
  static String? Function(dynamic) combine(
    List<String? Function(dynamic)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final error = validator(value);
        if (error != null) {
          return error;
        }
      }
      return null;
    };
  }
}
