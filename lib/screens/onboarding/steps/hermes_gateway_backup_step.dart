library screens.onboarding.steps.hermes_gateway_backup_step;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../services/hermes_manager/hermes_manager.dart';

final Logger _log = Logger('HermesGatewayBackupStep');

class HermesGatewayBackupStep extends StatefulWidget {
  @override
  State<HermesGatewayBackupStep> createState() =>
      _HermesGatewayBackupStepState();
}

class _HermesGatewayBackupStepState extends State<HermesGatewayBackupStep> {
  String _backupDir = '/var/lib/hermes/backups';
  bool _autoBackup = true;
  int _backupFrequency = 24; // hours

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Backup',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          initialValue: _backupDir,
          decoration: const InputDecoration(
            labelText: 'Backup Directory',
            hintText: '/var/lib/hermes/backups',
          ),
          onChanged: (value) {
            setState(() => _backupDir = value);
          },
        ),
        SwitchListTile(
          title: const Text('Enable Automatic Backups'),
          value: _autoBackup,
          onChanged: (value) {
            setState(() => _autoBackup = value);
          },
        ),
        if (_autoBackup)
          TextField(
            initialValue: _backupFrequency.toString(),
            decoration: const InputDecoration(
              labelText: 'Backup Frequency (hours)',
              hintText: '24 (daily)',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() =>
                  _backupFrequency = int.tryParse(value) ?? _backupFrequency);
            },
          ),
      ]).toList(),
    );
  }
}