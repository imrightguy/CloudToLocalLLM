import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestModelErrorStep');

class HermesGatewayTestModelErrorStep extends StatefulWidget {
  const HermesGatewayTestModelErrorStep({super.key});

  @override
  State<HermesGatewayTestModelErrorStep> createState() =>
      _HermesGatewayTestModelErrorState();
}

class _HermesGatewayTestModelErrorState
    extends State<HermesGatewayTestModelErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_off, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Model Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The selected model is not available or cannot be loaded. Please choose a different model.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Model error - showing model selection...');
          },
          icon: const Icon(Icons.model_training),
          label: const Text('Select Different Model'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Model error - showing available models...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.category),
          label: const Text('View Available Models'),
        ),
      ],
    );
  }
}
