import 'package:flutter/material.dart';

class HermesGatewayStorageStep extends StatefulWidget {
  const HermesGatewayStorageStep({super.key});

  @override
  State<HermesGatewayStorageStep> createState() =>
      _HermesGatewayStorageStepState();
}

class _HermesGatewayStorageStepState extends State<HermesGatewayStorageStep> {
  String _cacheDir = '/var/lib/hermes/cache';
  String _modelDir = '/usr/local/share/hermes/models';
  late TextEditingController _cacheDirController;
  late TextEditingController _modelDirController;
  bool _enableDiskCache = true;

  @override
  void initState() {
    super.initState();
    _cacheDirController = TextEditingController(text: _cacheDir);
    _modelDirController = TextEditingController(text: _modelDir);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Storage',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _cacheDirController,
          decoration: const InputDecoration(
            labelText: 'Cache Directory',
            hintText: '/var/lib/hermes/cache',
          ),
          onChanged: (value) {
            setState(() => _cacheDir = value);
          },
        ),
        TextField(
          controller: _modelDirController,
          decoration: const InputDecoration(
            labelText: 'Model Directory',
            hintText: '/usr/local/share/hermes/models',
          ),
          onChanged: (value) {
            setState(() => _modelDir = value);
          },
        ),
        SwitchListTile(
          title: const Text('Enable Disk Caching'),
          value: _enableDiskCache,
          onChanged: (value) {
            setState(() => _enableDiskCache = value);
          },
          subtitle: const Text(
              'Cache model weights and conversation history on disk'),
        ),
      ]).toList(),
    );
  }
}
