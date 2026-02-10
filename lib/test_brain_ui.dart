import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/components/brain_insight_widget.dart';
import 'package:cloudtolocalllm/database/local_brain.dart';
import 'package:cloudtolocalllm/di/locator.dart';
import 'package:get_it/get_it.dart';
import 'package:drift/drift.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Minimal locator setup for test
  final brain = LocalBrain();
  GetIt.instance.registerSingleton<LocalBrain>(brain);
  
  // Seed some test data
  await brain.into(brain.agentLogs).insert(AgentLogsCompanion.insert(
    level: 'info',
    message: 'Local Brain Initialized',
    context: 'Startup',
  ));
  
  await brain.into(brain.agentLogs).insert(AgentLogsCompanion.insert(
    level: 'warn',
    message: 'Optimizing SQLite with PRAGMA WAL',
    context: 'Performance Tuning',
  ));

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: BrainInsightWidget(),
    ),
  ));
}
