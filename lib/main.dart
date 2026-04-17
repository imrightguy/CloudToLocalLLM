
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:logging/logging.dart';

import 'services/auth/auth_provider.dart';
import 'services/auth/auth_service.dart';
import 'services/bootstrap/bootstrapper.dart';
import 'services/connection_manager_service.dart';
import 'services/hermes_manager/hermes_manager.dart';
import 'services/openclaw_manager/gateway_control_service.dart';
import 'services/provider_configuration_manager.dart';
import 'services/router_server.dart';

final GetIt di = GetIt.instance;

/// Configure the service locator with all dependencies.
void configureDependencies() {
  // Core services
  di.registerSingleton<RouterServer>(RouterServer());
  di.registerSingleton<AuthService>(AuthService());
  di.registerSingleton<AuthProvider>(AuthProvider());

  // Gateway services
  di.registerSingleton<GatewayControlService>(
      GatewayControlService(), instanceName: 'openclawGateway');
  di.registerSingleton<HermesGatewayControlService>(
      HermesGatewayControlService(), instanceName: 'hermesGateway');

  // Connection manager
  di.registerSingleton<ConnectionManagerService>(ConnectionManagerService(
    openclawGatewayService: di('openclawGateway'),
    hermesGatewayService: di('hermesGateway'),
  ));

  // Provider configuration
  di.registerSingleton<ProviderConfigurationManager>(
      ProviderConfigurationManager());
}

void main() {
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    developer.log(
      '[${record.level.name}] ${record.time}: ${record.message}',
      name: record.loggerName,
    );
  });

  // Configure dependencies
  configureDependencies();

  // Run the app
  runApp(const CloudToLocalLLMApp());
}

class CloudToLocalLLMApp extends StatelessWidget {
  const CloudToLocalLLMApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CloudToLocalLLM',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const Bootstrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}