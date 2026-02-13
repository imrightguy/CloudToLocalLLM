import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/services/behavior_warnings_service.dart';
import 'package:intl/intl.dart';

/// Behavior Warnings Widget
///
/// Displays active behavior warnings and allows acknowledgment.
/// Shows warnings in a snackbar/toast format for user feedback.
class BehaviorWarningsWidget extends StatefulWidget {
  final String? sessionKey;

  const BehaviorWarningsWidget({
    super.key,
    this.sessionKey,
  });

  @override
  State<BehaviorWarningsWidget> createState() => _BehaviorWarningsWidgetState();
}

class _BehaviorWarningsWidgetState extends State<BehaviorWarningsWidget> {
  final BehaviorWarningsService _service = BehaviorWarningsService();
  List<Warning> _warnings = [];

  @override
  void initState() {
    super.initState();
    _loadWarnings();
    _startAutoRefresh();
  }

  Future<void> _loadWarnings() async {
    try {
      _warnings = await _service.getWarnings(sessionKey: widget.sessionKey);
      setState(() {});
    } catch (e) {
      debugPrint('Failed to load warnings: $e');
    }
  }

  void _startAutoRefresh() {
    // Refresh warnings every 30 seconds
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 30));
      if (mounted) {
        await _loadWarnings();
      }
      return mounted;
    });
  }

  Future<void> _acknowledgeWarning(Warning warning) async {
    try {
      await _service.acknowledgeWarning(warning.id);
      setState(() {
        _warnings.removeWhere((w) => w.id == warning.id);
      });
    } catch (e) {
      debugPrint('Failed to acknowledge warning: $e');
    }
  }

  Color _getSeverityColor(Severity severity) {
    switch (severity) {
      case Severity.warning:
        return Colors.orange;
      case Severity.error:
        return Colors.red;
      case Severity.info:
        return Colors.blue;
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm:ss').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _getSeverityColor(
          _warnings.isEmpty ? Severity.info : _warnings.first.severity),
      child: SizedBox(
        width: double.infinity,
        child: _warnings.isEmpty
            ? const SizedBox.shrink()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var warning in _warnings)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: _buildWarningCard(warning),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildWarningCard(Warning warning) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          warning.severity == Severity.error
              ? Icons.error_outline
              : Icons.warning_amber_rounded,
          color: _getSeverityColor(warning.severity),
        ),
        title: Text(
          warning.message,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatTime(warning.triggeredAt)} | ${warning.severity.toString().split('.').last}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.check),
          onPressed: () => _acknowledgeWarning(warning),
        ),
      ),
    );
  }
}
