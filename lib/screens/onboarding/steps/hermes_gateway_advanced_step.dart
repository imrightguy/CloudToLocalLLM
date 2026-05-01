import 'package:flutter/material.dart';

class HermesGatewayAdvancedStep extends StatefulWidget {
  const HermesGatewayAdvancedStep({super.key});

  @override
  State<HermesGatewayAdvancedStep> createState() =>
      _HermesGatewayAdvancedStepState();
}

class _HermesGatewayAdvancedStepState extends State<HermesGatewayAdvancedStep> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showAdvanced = !_showAdvanced);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_showAdvanced ? 'Hide Advanced' : 'Show Advanced'),
                    const SizedBox(width: 8),
                    Icon(_showAdvanced
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showAdvanced)
          Column(
            children: ListTile.divideTiles(context: context, tiles: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Additional CLI Arguments',
                  hintText: '--model-path /path/to/model',
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Environment Variables',
                  hintText: 'KEY=VALUE',
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Debug Logging'),
                value: false,
                onChanged: (value) {
                  // Toggle debug logging
                },
              ),
              SwitchListTile(
                title: const Text('Enable Metrics Collection'),
                value: false,
                onChanged: (value) {
                  // Toggle metrics
                },
              ),
            ]).toList(),
          ),
      ],
    );
  }
}
