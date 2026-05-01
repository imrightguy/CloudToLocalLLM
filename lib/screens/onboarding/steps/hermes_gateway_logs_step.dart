import 'package:flutter/material.dart';

class HermesGatewayLogsStep extends StatefulWidget {
  const HermesGatewayLogsStep({super.key});

  @override
  State<HermesGatewayLogsStep> createState() => _HermesGatewayLogsStepState();
}

class _HermesGatewayLogsStepState extends State<HermesGatewayLogsStep> {
  String _logs = 'Hermes gateway logs will appear here...';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Gateway Logs',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_logs),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            // Refresh logs
            setState(() => _logs = 'Refreshing logs...');
          },
          child: const Text('Refresh Logs'),
        ),
      ]).toList(),
    );
  }
}
