import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../services/hermes_manager/hermes_gateway_control_service.dart';
import '../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayCategory');

/// Settings category for hermes-agent gateway configuration.
class HermesGatewayCategory extends StatefulWidget {
  final String? hermesUrl;
  final String? hermesApiKey;
  final bool hermesEnabled;

  const HermesGatewayCategory({
    super.key,
    this.hermesUrl,
    this.hermesApiKey,
    this.hermesEnabled = false,
  });

  @override
  State<HermesGatewayCategory> createState() => _HermesGatewayCategoryState();
}

class _HermesGatewayCategoryState extends State<HermesGatewayCategory> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isGatewayRunning = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.hermesUrl ?? '';
    _apiKeyController.text = widget.hermesApiKey ?? '';
    _isGatewayRunning = widget.hermesEnabled;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _startGateway() async {
    final service = HermesGatewayControlService();
    final success = await service.start();
    if (success) {
      setState(() => _isGatewayRunning = true);
      _log.info('Hermes gateway started');
    } else {
      _log.severe('Failed to start Hermes gateway');
      // Show error dialog
    }
  }

  Future<void> _stopGateway() async {
    final service = HermesGatewayControlService();
    final success = await service.stop();
    if (success) {
      setState(() => _isGatewayRunning = false);
      _log.info('Hermes gateway stopped');
    } else {
      _log.severe('Failed to stop Hermes gateway');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Hermes Gateway'),
      children: [
        ListTile(
          title: TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Hermes URL',
              hintText: 'http://localhost:1337',
            ),
          ),
        ),
        ListTile(
          title: TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: 'Optional for local hermes-agent',
            ),
            obscureText: true,
          ),
        ),
        OverflowBar(
          children: [
            ElevatedButton(
              onPressed: _isGatewayRunning ? null : _startGateway,
              child: const Text('Start'),
            ),
            ElevatedButton(
              onPressed: _isGatewayRunning ? _stopGateway : null,
              style: ElevatedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Stop'),
            ),
          ],
        ),
        if (_isGatewayRunning)
          ListTile(
            title: const Text('Hermes gateway is running'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                final service = HermesGatewayControlService();
                final success = await service.restart();
                if (!success) {
                  _log.severe('Hermes gateway restart failed');
                }
              },
              tooltip: 'Restart Hermes gateway',
            ),
          ),
      ],
    );
  }
}