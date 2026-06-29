import 'package:cloudtolocalllm/config/app_config.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';

/// Provider Discovery Service
/// Discovers agent runtimes and optional support model providers.

class ProviderDiscoveryService {
  static const Duration _scanTimeout = Duration(seconds: 10);

  /// Scan for all known endpoint types on the network.
  ///
  /// Agent runtimes are valid main-channel targets. Support model providers
  /// are background helpers only and cannot satisfy setup.
  Future<List<ProviderInfo>> scanForProviders() async {
    debugPrint('[ProviderDiscovery] Scanning for providers...');

    final runtimes = await scanForAgentRuntimes();
    final supportProviders = await scanForSupportModelProviders();
    final discovered = <ProviderInfo>[
      ...runtimes,
      ...supportProviders,
    ];

    debugPrint('[ProviderDiscovery] Found ${discovered.length} providers');
    return discovered;
  }

  /// Scan only for agent runtimes that can drive the main secure channel.
  Future<List<ProviderInfo>> scanForAgentRuntimes() async {
    debugPrint('[ProviderDiscovery] Scanning for agent runtimes...');

    final List<ProviderInfo> discovered = [];
    final List<Future<ProviderInfo?>> scans = [
      _scanHermes(),
      _scanOpenClawGateway(),
    ];

    try {
      final results = await Future.wait(scans, eagerError: false);
      for (final result in results) {
        if (result != null) {
          discovered.add(result);
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Runtime scan error: $e');
    }

    debugPrint(
      '[ProviderDiscovery] Found ${discovered.length} agent runtimes',
    );
    return discovered;
  }

  /// Scan for optional local model providers used by memory/helper tasks.
  Future<List<ProviderInfo>> scanForSupportModelProviders() async {
    debugPrint('[ProviderDiscovery] Scanning for support model providers...');

    final List<ProviderInfo> discovered = [];
    final List<Future<ProviderInfo?>> scans = [
      _scanLMStudio(),
      _scanOllama(),
    ];

    try {
      final results = await Future.wait(scans, eagerError: false);
      for (final result in results) {
        if (result != null) {
          discovered.add(result);
        }
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Support provider scan error: $e');
    }

    debugPrint(
      '[ProviderDiscovery] Found ${discovered.length} support model providers',
    );
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
          role: ProviderRole.agentRuntime,
        );
      }
    } catch (_) {
      // Not available — expected on this machine
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
          role: ProviderRole.supportModelProvider,
        );
      }
    } catch (_) {
      // Not available — expected on this machine
    }
    return null;
  }

  /// Scan for Hermes Agent on localhost:8642 (or configurable URL)
  Future<ProviderInfo?> _scanHermes() async {
    final settings = SettingsPreferenceService();
    final configuredUrl = await settings.getHermesUrl();
    final baseUrl = (configuredUrl?.isNotEmpty ?? false)
        ? configuredUrl!
        : AppConfig.defaultHermesUrl;
    final healthUrl = Uri.parse('$baseUrl/health');

    try {
      final response = await http.get(healthUrl).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        // Read API key from SharedPreferences, fallback to .env file
        var apiKey = await settings.getHermesApiKey();
        apiKey ??= await _discoverHermesApiKeyFromEnv();

        // Fetch models — Hermes is discovered even if model fetch fails
        // (health check success is enough to report the runtime as available)
        List<String> models = const [];
        try {
          models = await _fetchOpenAICompatibleModels(baseUrl, apiKey: apiKey);
        } catch (e) {
          debugPrint(
              '[ProviderDiscovery] Model fetch failed for Hermes (non-fatal): $e');
        }

        debugPrint('[ProviderDiscovery] Found Hermes Agent at $baseUrl');
        return ProviderInfo(
          id: 'hermes_discovered',
          type: ProviderType.hermes,
          name: 'Hermes Agent',
          url: baseUrl,
          isLocal: true,
          isAvailable: true,
          version: _extractVersion(response.body),
          availableModels: models,
          role: ProviderRole.agentRuntime,
        );
      }
    } catch (e) {
      debugPrint('[ProviderDiscovery] Hermes Agent not available: $e');
    }
    return null;
  }

  /// Try to discover the Hermes API server key from the .env file.
  /// Searches common locations on Windows/Linux/macOS.
  Future<String?> _discoverHermesApiKeyFromEnv() async {
    if (kIsWeb) return null;

    final envPaths = <String>[
      '${Platform.environment['HERMES_HOME'] ?? ''}/.env',
      '${Platform.environment['LOCALAPPDATA'] ?? ''}/hermes/.env',
      '${Platform.environment['HOME'] ?? ''}/.hermes/.env',
      '${Platform.environment['USERPROFILE'] ?? ''}/.hermes/.env',
    ];

    for (final path in envPaths) {
      if (path.isEmpty) continue;
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final contents = await file.readAsString();
        for (final line in contents.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.startsWith('API_SERVER_KEY=')) {
            final key = trimmed.substring('API_SERVER_KEY='.length).trim();
            if (key.isNotEmpty) {
              debugPrint(
                  '[ProviderDiscovery] Found API_SERVER_KEY in $path');
              return key;
            }
          }
        }
      } catch (e) {
        debugPrint('[ProviderDiscovery] Error reading $path: $e');
      }
    }
    return null;
  }

  /// Scan for Ollama on localhost:11434
  Future<ProviderInfo?> _scanOllama() async {
    const host = '127.0.0.1';
    const port = 11434;
    const baseUrl = 'http://$host:$port';
    final tagsUrl = Uri.parse('$baseUrl/api/tags');

    try {
      final response = await http.get(tagsUrl).timeout(_scanTimeout);

      if (response.statusCode == 200) {
        final models = _extractOllamaModels(response.body);
        debugPrint('[ProviderDiscovery] Found Ollama at $baseUrl');
        return ProviderInfo(
          id: 'ollama_discovered',
          type: ProviderType.ollama,
          name: 'Ollama',
          url: baseUrl,
          isLocal: true,
          isAvailable: true,
          availableModels: models,
          role: ProviderRole.supportModelProvider,
        );
      }
    } catch (_) {
      // Not available — expected on this machine
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

  Future<List<String>> _fetchOpenAICompatibleModels(
    String baseUrl, {
    String? apiKey,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/v1/models');
      final headers = <String, String>{};
      if (apiKey != null && apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      final response =
          await http.get(url, headers: headers).timeout(_scanTimeout);
      if (response.statusCode != 200) {
        debugPrint(
            '[ProviderDiscovery] /v1/models returned ${response.statusCode} from $baseUrl');
        return const [];
      }
      final data = jsonDecode(response.body);
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((model) => model['id']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint(
          '[ProviderDiscovery] Failed to fetch models from $baseUrl: $e');
    }
    return const [];
  }

  List<String> _extractOllamaModels(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data['models'] is List) {
        return (data['models'] as List)
            .whereType<Map>()
            .map((model) =>
                model['name']?.toString() ?? model['model']?.toString())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList(growable: false);
      }
    } catch (e) {
      // Ignore parse errors; provider availability matters more than model list.
    }
    return const [];
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
