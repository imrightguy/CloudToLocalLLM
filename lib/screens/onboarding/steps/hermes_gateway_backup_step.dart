import 'package:flutter/material.dart';

class HermesGatewayBackupStep extends StatefulWidget {
  const HermesGatewayBackupStep({super.key});

  @override
  State<HermesGatewayBackupStep> createState() =>
      _HermesGatewayBackupStepState();
}

class _HermesGatewayBackupStepState extends State<HermesGatewayBackupStep> {
  String _backupDir = '/var/lib/hermes/backups';
  bool _autoBackup = true;
  int _backupFrequency = 24; // hours
  late TextEditingController _backupDirController;
  late TextEditingController _backupFrequencyController;

  @override
  void initState() {
    super.initState();
    _backupDirController = TextEditingController(text: _backupDir);
    _backupFrequencyController =
        TextEditingController(text: _backupFrequency.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: ListTile.divideTiles(context: context, tiles: [
        Text(
          'Hermes Gateway Backup',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        TextField(
          controller: _backupDirController,
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
            controller: _backupFrequencyController,
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
