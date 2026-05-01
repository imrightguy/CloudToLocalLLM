import 'package:flutter/material.dart';

class HermesGatewaySummaryStep extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;
  final bool hermesEnabled;

  const HermesGatewaySummaryStep({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
    this.hermesEnabled = false,
  });

  @override
  State<HermesGatewaySummaryStep> createState() =>
      _HermesGatewaySummaryStepState();
}

class _HermesGatewaySummaryStepState extends State<HermesGatewaySummaryStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Configuration Summary',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        if (widget.hermesEnabled)
          Column(
            children: [
              Text('Gateway URL: ${widget.hermesUrl}'),
              Text(
                  'API Key: ${widget.hermesApiKey != null ? 'Set' : 'Not set'}'),
              const SizedBox(height: 16),
              const Text(
                'Hermes gateway is enabled and ready to use!',
                style: TextStyle(color: Colors.green),
              ),
            ],
          ),
        if (!widget.hermesEnabled)
          const Text(
            'Hermes gateway is disabled. Enable it in settings to use Hermes as a backend.',
            style: TextStyle(color: Colors.red),
          ),
      ]).toList(),
    );
  }
}
