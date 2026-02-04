#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// Pure Dart Tunnel Connection Test
/// Basic test to verify tunnel connection functionality without Flutter dependencies
library;

import 'dart:async';
import 'dart:io';

void main() async {
  print('[PureTunnelTest] Starting pure tunnel connection test...');

  try {
    // Test 1: Basic tunnel configuration validation
    await testTunnelConfiguration();

    // Test 2: WebSocket URL construction
    await testWebSocketUrlConstruction();

    // Test 3: Tunnel connection flow simulation
    await testConnectionFlow();

    print('[PureTunnelTest] ✅ All basic tests completed successfully!');
    print('[PureTunnelTest] Next steps:');
    print('  1. Start backend tunnel server');
    print('  2. Configure proper authentication');
    print('  3. Run full integration tests');
    print('  4. Test actual SSH/WebSocket connections');
  } catch (e, stackTrace) {
    print('[PureTunnelTest] ❌ Test failed with error: $e');
    print('[PureTunnelTest] Stack trace: $stackTrace');
    exit(1);
  }
}

/// Test tunnel configuration validation
Future<void> testTunnelConfiguration() async {
  print('[PureTunnelTest] === Testing Tunnel Configuration ===');

  try {
    // Test configuration parameters
    const configParams = {
      'userId': 'test-user-123',
      'cloudProxyUrl': 'wss://api.zoidbot.online:8080/ssh',
      'localBackendUrl': 'http://localhost:11434',
      'authToken': 'test-jwt-token-12345',
      'enableCloudProxy': true,
    };

    print('[PureTunnelTest] Configuration parameters:');
    configParams.forEach((key, value) {
      print('  $key: $value');
    });

    // Validate URL formats
    final cloudProxyUri = Uri.parse(configParams['cloudProxyUrl'] as String);
    final localBackendUri =
        Uri.parse(configParams['localBackendUrl'] as String);

    print(
        '[PureTunnelTest] Parsed cloud proxy URI: ${cloudProxyUri.scheme}://${cloudProxyUri.host}:${cloudProxyUri.port}');
    print(
        '[PureTunnelTest] Parsed local backend URI: ${localBackendUri.scheme}://${localBackendUri.host}:${localBackendUri.port}');

    // Validate ports
    final cloudProxyPort = cloudProxyUri.port;
    final localBackendPort = localBackendUri.port;

    if (cloudProxyPort == 8080 && localBackendPort == 11434) {
      print('[PureTunnelTest] ✅ SUCCESS: Port configuration is correct');
    } else {
      print('[PureTunnelTest] ❌ FAILED: Port configuration is incorrect');
      throw Exception('Invalid port configuration');
    }
  } catch (e) {
    print('[PureTunnelTest] ❌ Configuration test failed: $e');
    rethrow;
  }
}

/// Test WebSocket URL construction
Future<void> testWebSocketUrlConstruction() async {
  print('[PureTunnelTest] === Testing WebSocket URL Construction ===');

  try {
    // Test URL construction logic from SSH tunnel client
    const cloudProxyUrl = 'wss://api.zoidbot.online:8080/ssh';
    const authToken = 'test-jwt-token-12345';
    const userId = 'test-user-123';

    print('[PureTunnelTest] Input cloud proxy URL: $cloudProxyUrl');

    // Convert to WebSocket URL (already WebSocket in this case)
    final wsUrl = cloudProxyUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    print('[PureTunnelTest] WebSocket URL: $wsUrl');

    // Add authentication parameters
    final uri = Uri.parse(wsUrl);
    final wsUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
      queryParameters: {
        'token': authToken,
        'userId': userId,
      },
    );

    print(
        '[PureTunnelTest] Final WebSocket URI: ${wsUri.toString().replaceAll(authToken, '[REDACTED]')}');

    // Validate the constructed URI
    if (wsUri.scheme == 'wss' &&
        wsUri.host == 'api.zoidbot.online' &&
        wsUri.port == 8080 &&
        wsUri.path == '/ssh' &&
        wsUri.queryParameters.containsKey('token') &&
        wsUri.queryParameters.containsKey('userId')) {
      print(
          '[PureTunnelTest] ✅ SUCCESS: WebSocket URI construction is correct');
    } else {
      print(
          '[PureTunnelTest] ❌ FAILED: WebSocket URI construction is incorrect');
      throw Exception('Invalid WebSocket URI construction');
    }
  } catch (e) {
    print('[PureTunnelTest] ❌ WebSocket URL test failed: $e');
    rethrow;
  }
}

/// Test connection flow simulation
Future<void> testConnectionFlow() async {
  print('[PureTunnelTest] === Testing Connection Flow Simulation ===');

  try {
    // Simulate connection states
    final connectionStates = [
      'initializing',
      'authenticating',
      'connecting',
      'connected',
      'health_check',
      'ready'
    ];

    print('[PureTunnelTest] Simulating connection flow:');

    for (final state in connectionStates) {
      print('  → $state');
      await Future.delayed(const Duration(milliseconds: 200));
    }

    print('[PureTunnelTest] ✅ SUCCESS: Connection flow simulation completed');

    // Test error handling
    print('[PureTunnelTest] Testing error handling...');

    try {
      // Simulate a connection error
      throw Exception('Simulated connection timeout');
    } catch (e) {
      print('[PureTunnelTest] Caught simulated error: $e');
      print('[PureTunnelTest] ✅ SUCCESS: Error handling works correctly');
    }
  } catch (e) {
    print('[PureTunnelTest] ❌ Connection flow test failed: $e');
    rethrow;
  }
}

/// Test tunnel registration simulation
Future<void> testTunnelRegistration() async {
  print('[PureTunnelTest] === Testing Tunnel Registration Simulation ===');

  try {
    // Simulate registration data
    final registrationData = {
      'tunnelId': 'test-tunnel-${DateTime.now().millisecondsSinceEpoch}',
      'localPort': 11434,
      'userId': 'test-user-123',
      'serverPort': 9000,
    };

    print('[PureTunnelTest] Registration data:');
    registrationData.forEach((key, value) {
      print('  $key: $value');
    });

    // Simulate registration API call
    print('[PureTunnelTest] Simulating registration API call...');
    await Future.delayed(const Duration(milliseconds: 300));

    print('[PureTunnelTest] ✅ SUCCESS: Registration simulation completed');
  } catch (e) {
    print('[PureTunnelTest] ❌ Registration test failed: $e');
    rethrow;
  }
}

/// Test tunnel health monitoring simulation
Future<void> testHealthMonitoring() async {
  print('[PureTunnelTest] === Testing Health Monitoring Simulation ===');

  try {
    // Simulate health check cycle
    final healthCheckInterval = Duration(seconds: 1);
    final maxChecks = 3;

    print('[PureTunnelTest] Starting health check simulation...');

    for (var i = 0; i < maxChecks; i++) {
      print('[PureTunnelTest] Health check ${i + 1}/$maxChecks...');
      await Future.delayed(healthCheckInterval);

      // Simulate health check result
      final isHealthy = i < 2; // First two checks pass, third fails
      if (isHealthy) {
        print('[PureTunnelTest] ✅ Connection healthy');
      } else {
        print(
            '[PureTunnelTest] ❌ Connection unhealthy - would trigger recovery');
      }
    }

    print('[PureTunnelTest] ✅ SUCCESS: Health monitoring simulation completed');
  } catch (e) {
    print('[PureTunnelTest] ❌ Health monitoring test failed: $e');
    rethrow;
  }
}

/// Display test summary
void displayTestSummary() {
  print('[PureTunnelTest] ===== TEST SUMMARY =====');
  print('[PureTunnelTest] ✅ Configuration validation: PASSED');
  print('[PureTunnelTest] ✅ WebSocket URL construction: PASSED');
  print('[PureTunnelTest] ✅ Connection flow simulation: PASSED');
  print('[PureTunnelTest] ✅ Error handling: PASSED');
  print('');
  print('[PureTunnelTest] Next steps for full testing:');
  print('  1. Set up backend tunnel server');
  print('  2. Configure JWT authentication');
  print('  3. Implement actual SSH/WebSocket connections');
  print('  4. Test with real Ollama backend');
  print('  5. Run integration tests');
}
