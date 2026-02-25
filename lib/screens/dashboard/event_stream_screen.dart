/// Event Stream Screen - Stub Implementation
library;

import 'package:flutter/material.dart';

/// Agent Event model - local stub
class AgentEvent {
  final String eventType;
  final Map<String, dynamic> eventData;
  final DateTime timestamp;

  AgentEvent({
    required this.eventType,
    required this.eventData,
    required this.timestamp,
  });
}

/// Event Stream Screen - stub
class EventStreamScreen extends StatelessWidget {
  const EventStreamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.stream, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('Event stream not available',
              style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
