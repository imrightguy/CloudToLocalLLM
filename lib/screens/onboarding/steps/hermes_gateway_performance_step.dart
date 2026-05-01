import 'package:flutter/material.dart';

class HermesGatewayPerformanceStep extends StatefulWidget {
  const HermesGatewayPerformanceStep({super.key});

  @override
  State<HermesGatewayPerformanceStep> createState() =>
      _HermesGatewayPerformanceStepState();
}

class _HermesGatewayPerformanceStepState
    extends State<HermesGatewayPerformanceStep> {
  int _maxConcurrentRequests = 10;
  int _requestTimeout = 30;
  int _maxTokens = 4096;
  late TextEditingController _maxConcurrentController;
  late TextEditingController _requestTimeoutController;
  late TextEditingController _maxTokensController;

  @override
  void initState() {
    super.initState();
    _maxConcurrentController =
        TextEditingController(text: _maxConcurrentRequests.toString());
    _requestTimeoutController =
        TextEditingController(text: _requestTimeout.toString());
    _maxTokensController = TextEditingController(text: _maxTokens.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Performance',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _maxConcurrentController,
          decoration: const InputDecoration(
            labelText: 'Max Concurrent Requests',
            hintText: '10 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() => _maxConcurrentRequests =
                int.tryParse(value) ?? _maxConcurrentRequests);
          },
        ),
        TextField(
          controller: _requestTimeoutController,
          decoration: const InputDecoration(
            labelText: 'Request Timeout (seconds)',
            hintText: '30 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(
                () => _requestTimeout = int.tryParse(value) ?? _requestTimeout);
          },
        ),
        TextField(
          controller: _maxTokensController,
          decoration: const InputDecoration(
            labelText: 'Max Tokens per Request',
            hintText: '4096 (default)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            setState(() => _maxTokens = int.tryParse(value) ?? _maxTokens);
          },
        ),
      ]).toList(),
    );
  }
}
