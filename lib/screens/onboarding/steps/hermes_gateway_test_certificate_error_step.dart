import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('HermesGatewayTestCertificateErrorStep');

class HermesGatewayTestCertificateErrorStep extends StatefulWidget {
  const HermesGatewayTestCertificateErrorStep({super.key});

  @override
  State<HermesGatewayTestCertificateErrorStep> createState() =>
      _HermesGatewayTestCertificateErrorState();
}

class _HermesGatewayTestCertificateErrorState
    extends State<HermesGatewayTestCertificateErrorStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.verified_user, color: Colors.red, size: 80),
        const SizedBox(height: 16),
        const Text(
          'Certificate Error',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'The security certificate for Hermes gateway is not trusted. This may be because it is self-signed or issued by an unknown authority.',
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Certificate error - continuing anyway...');
          },
          icon: const Icon(Icons.warning),
          label: const Text('Continue Anyway (insecure)'),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            _log.info('Certificate error - importing certificate...');
          },
          style: ElevatedButton.styleFrom(foregroundColor: Colors.grey),
          icon: const Icon(Icons.download),
          label: const Text('Import Certificate'),
        ),
      ],
    );
  }
}
