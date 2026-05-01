import 'package:flutter/material.dart';

class HermesGatewayMetricsStep extends StatefulWidget {
  const HermesGatewayMetricsStep({super.key});

  @override
  State<HermesGatewayMetricsStep> createState() =>
      _HermesGatewayMetricsStepState();
}

class _HermesGatewayMetricsStepState extends State<HermesGatewayMetricsStep> {
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
