import 'package:cloudtolocalllm/config/app_config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// Provider Discovery Service
/// Discovers local LLM providers on the network

class ProviderDiscoveryService {
  static const Duration _scanTimeout = Duration(seconds: 3);

  /// Scan for available LLM providers on the network
  Future<List<ProviderInfo>> scanForProviders() async {
    debugPrint('[ProviderDiscovery] Scanning for providers...');

    final List<ProviderInfo> discovered = [];
    final List<Future<ProviderInfo?>> scans = [
      _scanOpenClawGateway(),
      _scanLMStudio(),
      // Ollama is handled by the LLM router, not as a separate provider
    ];

    try {
      final results = await Future.wait(scans, eagerError: false);
      for (final result in results) {
        if (result != null) {
          discovered.add(result);
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Scan error: $e');
    }

    debugPrint('[ProviderDiscovery] Found ${discovered.length} providers');
    return discovered;
  }

  /// Scan for OpenClaw Gateway on localhost:18789
  Future<ProviderInfo?> _scanOpenClawGateway() async {
    final host = AppConfig.gatewayHost;
    const port = 18789;
    final baseUrl = 'http://$host:$port';
    final healthUrl = Uri.parse('$baseUrl/health');

    try {
      final response = await http.get(healthUrl).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        debugPrint('[ProviderDiscovery] Found OpenClaw Gateway at $baseUrl');
        return ProviderInfo(
          id: 'openclaw_discovered',
          type: ProviderType.openclaw,
          name: 'OpenClaw Gateway',
          url: baseUrl,
          isLocal: true,
          isAvailable: true,
          version: _extractVersion(response.body),
        );
      }
    } catch (e) {
      // Not an error - just not available
      debugPrint('[ProviderDiscovery] OpenClaw Gateway not available: $e');
    }
    return null;
  }

  /// Scan for LM Studio on localhost:1234
  Future<ProviderInfo?> _scanLMStudio() async {
    const host = '127.0.0.1'; // LM Studio default - intentionally hardcoded
    const port = 1234;
    final url = Uri.parse('http://$host:$port/v1/models');

    try {
      final response = await http.get(url).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        debugPrint('[ProviderDiscovery] Found LM Studio at $url');
        return ProviderInfo(
          id: 'lmstudio_discovered',
          type: ProviderType.lmStudio,
          name: 'LM Studio',
          url: url.toString(),
          isLocal: true,
          isAvailable: true,
        );
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] LM Studio not available: $e');
    }
    return null;
  }

  /// Test connectivity to a specific URL
  Future<ConnectionTestResult> testConnection(String url) async {
    try {
      final uri = Uri.parse(url);
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return ConnectionTestResult(
          isConnected: true,
          url: url,
          statusCode: response.statusCode,
          message: 'Connected successfully',
        );
      } else {
        return ConnectionTestResult(
          isConnected: false,
          url: url,
          statusCode: response.statusCode,
          message: 'Server returned ${response.statusCode}',
        );
      }
    } catch (e) {
      return ConnectionTestResult(
        isConnected: false,
        url: url,
        message: 'Connection failed: ${e.toString()}',
      );
    }
  }

  /// Start periodic scanning for new providers
  Timer? _scanTimer;
  void startPeriodicScanning(
      {Duration interval = const Duration(seconds: 30)}) {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(interval, (_) {
      scanForProviders();
    });
    debugPrint('[ProviderDiscovery] Started periodic scanning');
  }

  /// Stop periodic scanning
  void stopPeriodicScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    debugPrint('[ProviderDiscovery] Stopped periodic scanning');
  }

  /// Check if a specific provider type is available
  Future<bool> isProviderTypeAvailable(ProviderType type) async {
    final providers = await scanForProviders();
    return providers.any((p) => p.type == type);
  }

  /// Discover Tailscale devices on the tailnet
  /// This requires Tailscale to be installed and authenticated
  Future<List<TailscaleDevice>> discoverTailscaleDevices() async {
    debugPrint('[ProviderDiscovery] Discovering Tailscale devices...');

    try {
      // Try to run 'tailscale status --json'
      final result = await Process.run('tailscale', ['status', '--json']);

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        return _parseTailscaleStatus(output);
      } else {
        debugPrint(
            '[ProviderDiscovery] Tailscale not available or not authenticated');
        return [];
      }
    } catch (e) {
      debugPrint(
          '[ProviderDiscovery] Failed to discover Tailscale devices: $e');
      return [];
    }
  }

  List<TailscaleDevice> _parseTailscaleStatus(String jsonOutput) {
    try {
      final dynamic data = jsonDecode(jsonOutput);
      final List<TailscaleDevice> devices = [];

      if (data is Map && data.containsKey('Peer')) {
        final peers = data['Peer'] as Map;
        peers.forEach((key, peer) {
          if (peer is Map) {
            final ips = _extractIPs(peer);

            // Filter out localhost devices to prevent duplicates
            // when the same machine is both localhost and on tailnet
            if (ips.any((ip) =>
                ip == '127.0.0.1' || ip == '::1' || ip == 'localhost')) {
              debugPrint(
                  '[ProviderDiscovery] Skipping localhost Tailscale device: ${peer['HostName']}');
              return;
            }

            final device = TailscaleDevice(
              name: peer['HostName']?.toString() ?? key.toString(),
              hostname: peer['DNSName']?.toString() ?? '',
              ips: ips,
              isOnline: peer['Online'] == true,
            );
            devices.add(device);
          }
        });
      }

      debugPrint(
          '[ProviderDiscovery] Found ${devices.length} Tailscale devices');
      return devices;
    } catch (e) {
      debugPrint('[ProviderDiscovery] Failed to parse Tailscale status: $e');
      return [];
    }
  }

  List<String> _extractIPs(Map<dynamic, dynamic> peer) {
    final List<String> ips = [];

    if (peer.containsKey('TailscaleIPs')) {
      final tailnetIps = peer['TailscaleIPs'];
      if (tailnetIps is List) {
        for (final ip in tailnetIps) {
          if (ip is String) {
            ips.add(ip);
          }
        }
      }
    }

    return ips;
  }

  String? _extractVersion(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data.containsKey('version')) {
        return data['version']?.toString();
      }
    } catch (e) {
      // Ignore parse errors
    }
    return null;
  }
}

/// Result of a connection test
class ConnectionTestResult {
  final bool isConnected;
  final String url;
  final int? statusCode;
  final String message;

  ConnectionTestResult({
    required this.isConnected,
    required this.url,
    this.statusCode,
    required this.message,
  });
}

/// Represents a Tailscale device on the tailnet
class TailscaleDevice {
  final String name;
  final String hostname;
  final List<String> ips;
  final bool isOnline;

  TailscaleDevice({
    required this.name,
    required this.hostname,
    required this.ips,
    required this.isOnline,
  });

  /// Get the primary IP address (first available)
  String? get primaryIP => ips.isNotEmpty ? ips.first : null;

  @override
  String toString() =>
      'TailscaleDevice(name: $name, hostname: $hostname, ips: $ips, online: $isOnline)';
}
