import 'package:flutter/material.dart';

class HermesGatewayTroubleshootingStep extends StatefulWidget {
  const HermesGatewayTroubleshootingStep({super.key});

  @override
  State<HermesGatewayTroubleshootingStep> createState() =>
      _HermesGatewayTroubleshootingStepState();
}

class _HermesGatewayTroubleshootingStepState
    extends State<HermesGatewayTroubleshootingStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Troubleshooting',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Text(
            'Having trouble? Check the following:\n\n1. Ensure hermes-agent is installed and in your PATH\n2. Verify the gateway is running: hermes-agent gateway status\n3. Check firewall settings: port 1337 should be open\n4. Review logs: journalctl -u hermes-agent\n5. Restart the gateway: hermes-agent gateway restart\n\nIf problems persist, visit the Hermes documentation or join the community forum.'),
      ]).toList(),
    );
  }
}
