/// Settings Error Display Widgets
///
/// Provides reusable widgets for displaying validation and error messages.
library;

import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/utils/settings_error_handler.dart';

/// Inline error message widget for form fields
class FieldErrorMessage extends StatelessWidget {
  /// Error message to display
  final String? errorMessage;

  /// Whether to show the error
  final bool show;

  const FieldErrorMessage({
    super.key,
    this.errorMessage,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!show || errorMessage == null || errorMessage!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Error notification banner for general errors
class ErrorNotificationBanner extends StatelessWidget {
  /// Error to display
  final SettingsError error;

  /// Callback when retry button is pressed
  final VoidCallback? onRetry;

  /// Callback when close button is pressed
  final VoidCallback? onClose;

  const ErrorNotificationBanner({
    super.key,
    required this.error,
    this.onRetry,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final color = SettingsErrorHandler.getErrorColor(error);
    final icon = SettingsErrorHandler.getErrorIcon(error);
    final message = SettingsErrorHandler.getUserMessage(error);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).toInt()),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (error.fieldErrors != null &&
                    error.fieldErrors!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...error.fieldErrors!.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '• ${entry.key}: ${entry.value}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error.isRetryable && onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    'Retry',
                    style: TextStyle(color: color),
                  ),
                ),
              if (onClose != null)
                TextButton(
                  onPressed: onClose,
                  child: Text(
                    'Close',
                    style: TextStyle(color: color),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Success notification banner
class SuccessNotificationBanner extends StatefulWidget {
  /// Success message to display
  final String message;

  /// Duration to show the banner
  final Duration duration;

  /// Callback when banner is dismissed
  final VoidCallback? onDismissed;

  const SuccessNotificationBanner({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 2),
    this.onDismissed,
  });

  @override
  State<SuccessNotificationBanner> createState() =>
      _SuccessNotificationBannerState();
}

class _SuccessNotificationBannerState extends State<SuccessNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismissed?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withAlpha((0.1 * 255).toInt()),
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _controller.reverse().then((_) {
                  widget.onDismissed?.call();
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Validation error list widget
class ValidationErrorList extends StatelessWidget {
  /// Map of field names to error messages
  final Map<String, String> errors;

  /// Callback when a field error is clicked
  final Function(String fieldName)? onFieldTapped;

  const ValidationErrorList({
    super.key,
    required this.errors,
    this.onFieldTapped,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha((0.1 * 255).toInt()),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade600),
              const SizedBox(width: 12),
              Text(
                'Please fix the following errors:',
                style: TextStyle(
                  color: Colors.orange.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...errors.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onFieldTapped?.call(entry.key),
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.value,
                            style: TextStyle(
                              color: Colors.orange.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading indicator for settings operations
class SettingsLoadingIndicator extends StatelessWidget {
  /// Message to display while loading
  final String message;

  const SettingsLoadingIndicator({
    super.key,
    this.message = 'Loading settings...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

/// Retry button widget
class RetryButton extends StatelessWidget {
  /// Callback when retry is pressed
  final VoidCallback onRetry;

  /// Whether the button is loading
  final bool isLoading;

  /// Custom label
  final String label;

  const RetryButton({
    super.key,
    required this.onRetry,
    this.isLoading = false,
    this.label = 'Retry',
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onRetry,
      icon: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh),
      label: Text(label),
    );
  }
}
