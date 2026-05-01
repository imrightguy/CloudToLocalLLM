import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestGatewayUpdateFailedStep');

class HermesGatewayTestGatewayUpdateFailedStep extends StatefulWidget {
  const HermesGatewayTestGatewayUpdateFailedStep({super.key});

  @override
  State<HermesGatewayTestGatewayUpdateFailedStep> createState() =>
      _HermesGatewayTestGatewayUpdateFailedState();
}

class _HermesGatewayTestGatewayUpdateFailedState
    extends State<HermesGatewayTestGatewayUpdateFailedStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.cloud_download, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Gateway Update Failed',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hermes gateway failed to update. Please check your internet connection and try again.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway update failed - checking connection...');
          },
          icon: const Icon(Icons.wifi),
          label: const Text('Check Internet Connection'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Gateway update failed - manual update...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.download),
          label: const Text('Manual Update'),
        ),
      ],
    );
  }
}
