

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';


final Logger _log = Logger('HermesGatewayMetricsStep');

class HermesGatewayMetricsStep extends StatefulWidget {
  @override
  State<HermesGatewayMetricsStep> createState() =>
      _HermesGatewayMetricsStepState();
}

class _HermesGatewayMetricsStepState extends State<HermesGatewayMetricsStep> {
  String _metrics = 'Uptime: 99.9%\nLatency: 120ms\nRequests: 1,234\nErrors: 0';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Gateway Metrics',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        ListTile(
          title: Text('Uptime'),
          trailing: Text('99.9%'),
        ),
        ListTile(
          title: Text('Average Latency'),
          trailing: Text('120ms'),
        ),
        ListTile(
          title: Text('Total Requests'),
          trailing: Text('1,234'),
        ),
        ListTile(
          title: Text('Error Rate'),
          trailing: Text('0%'),
        ),
      ]).toList(),
    );
  }
}