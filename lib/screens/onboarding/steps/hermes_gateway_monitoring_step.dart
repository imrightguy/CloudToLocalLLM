import 'package:flutter/material.dart';

class HermesGatewayMonitoringStep extends StatefulWidget {
  const HermesGatewayMonitoringStep({super.key});

  @override
  State<HermesGatewayMonitoringStep> createState() =>
      _HermesGatewayMonitoringStepState();
}

class _HermesGatewayMonitoringStepState
    extends State<HermesGatewayMonitoringStep> {
  bool _enableMetrics = true;
  bool _enableTracing = false;
  bool _enableAlerts = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Monitoring',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SwitchListTile(
          title: const Text('Enable Metrics Collection'),
          value: _enableMetrics,
          onChanged: (value) {
            setState(() => _enableMetrics = value);
          },
          subtitle:
              const Text('Collect performance metrics (Prometheus format)'),
        ),
        SwitchListTile(
          title: const Text('Enable Distributed Tracing'),
          value: _enableTracing,
          onChanged: (value) {
            setState(() => _enableTracing = value);
          },
          subtitle: const Text('Trace requests across services'),
        ),
        SwitchListTile(
          title: const Text('Enable Alerts'),
          value: _enableAlerts,
          onChanged: (value) {
            setState(() => _enableAlerts = value);
          },
          subtitle: const Text('Send alerts for critical events'),
        ),
      ]).toList(),
    );
  }
}
