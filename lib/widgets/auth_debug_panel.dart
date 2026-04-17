import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_logger.dart';

/// Debug panel for authentication logging
/// Only visible in debug mode and on web platform
class AuthDebugPanel extends StatefulWidget {
  const AuthDebugPanel({super.key});

  @override
  State<AuthDebugPanel> createState() => _AuthDebugPanelState();
}

class _AuthDebugPanelState extends State<AuthDebugPanel> {
  bool _isExpanded = false;
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  void _refreshLogs() {
    if (kIsWeb) {
      setState(() {
        _logs = AuthLogger.getLogs();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode and on web
    if (!kDebugMode || !kIsWeb) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isExpanded ? 400 : 200,
            maxHeight: _isExpanded ? 500 : 60,
          ),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  if (_isExpanded) {
                    _refreshLogs();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                      bottomLeft:
                          _isExpanded ? Radius.zero : Radius.circular(12),
                      bottomRight:
                          _isExpanded ? Radius.zero : Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bug_report, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Auth Debug',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              if (_isExpanded) ...[
                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logs: ${_logs.length}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Errors: ${_logs.where((l) => l.contains('[ERROR]')).length}',
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            AuthLogger.downloadLogs();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Debug log downloaded'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                          child: const Text('Download'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            AuthLogger.clearLogs();
                            _refreshLogs();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Debug log cleared'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            textStyle: const TextStyle(fontSize: 10),
                          ),
                          child: const Text('Clear'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Recent logs
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: ListView.builder(
                      itemCount: _logs.length > 10 ? 10 : _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[
                            _logs.length - 1 - index]; // Show newest first

                        Color levelColor = Colors.white70;
                        if (log.contains('[ERROR]')) {
                          levelColor = Colors.red;
                        }
                        if (log.contains('[WARNING]')) {
                          levelColor = Colors.orange;
                        }
                        if (log.contains('[INFO]')) {
                          levelColor = Colors.blue;
                        }
                        if (log.contains('[DEBUG]')) {
                          levelColor = Colors.grey;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log,
                                style: TextStyle(
                                  color: levelColor,
                                  fontSize: 10,
                                ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Refresh button
                Container(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _refreshLogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                      child: const Text('Refresh'),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
