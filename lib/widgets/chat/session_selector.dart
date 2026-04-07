import 'package:flutter/material.dart';

class SessionSelector extends StatefulWidget {
  final String currentSession;
  final ValueChanged<String> onSessionChanged;
  final bool enabled;

  const SessionSelector({
    required this.currentSession,
    required this.onSessionChanged,
    this.enabled = true,
    super.key,
  });

  @override
  State<SessionSelector> createState() => _SessionSelectorState();
}

class _SessionSelectorState extends State<SessionSelector> {
  final List<String> _sessions = ['main'];

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: widget.currentSession,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _sessions.map((session) {
        return DropdownMenuItem<String>(
          value: session,
          child: Text(session),
        );
      }).toList(),
      onChanged: widget.enabled
          ? (value) {
              widget.onSessionChanged(value!);
            }
          : null,
    );
  }
}
