library screens.onboarding.steps.hermes_gateway_storage_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayStorageStep');

class HermesGatewayStorageStep extends StatefulWidget {
  @override
  State<HermesGatewayStorageStep> createState() =>
      _HermesGatewayStorageStepState();
}

class _HermesGatewayStorageStepStepState extends State<HermesGatewayStorageStep> {
  String _cacheDir = '/var/lib/hermes/cache';
  String _modelDir = '/usr/local/share/hermes/models';
  bool _enableDiskCache = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Storage',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          initialValue: _cacheDir,
          decoration: const InputDecoration(
            labelText: 'Cache Directory',
            hintText: '/var/lib/hermes/cache',
          ),
          onChanged: (value) {
            setState(() => _cacheDir = value);
          },
        ),
        TextField(
          initialValue: _modelDir,
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
          subtitle:
              const Text('Cache model weights and conversation history on disk'),
        ),
      ]).toList(),
    );
  }
}