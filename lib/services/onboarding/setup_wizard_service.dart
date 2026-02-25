import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// Connection method selection
enum ConnectionMethod {
  local,
  tailscale,
  custom,
}

/// Setup wizard state
class WizardState {
  final int currentStep;
  final ConnectionMethod? selectedMethod;
  final List<ProviderInfo> discoveredProviders;
  final List<TailscaleDevice> tailscaleDevices;
  final String? customUrl;
  final ProviderInfo? selectedProvider;
  final String? gatewayPassword; // OpenClaw Gateway password/token
  final bool isLoading;
  final String? errorMessage;

  const WizardState({
    this.currentStep = 0,
    this.selectedMethod,
    this.discoveredProviders = const [],
    this.tailscaleDevices = const [],
    this.customUrl,
    this.selectedProvider,
    this.gatewayPassword,
    this.isLoading = false,
    this.errorMessage,
  });

  WizardState copyWith({
    int? currentStep,
    ConnectionMethod? selectedMethod,
    List<ProviderInfo>? discoveredProviders,
    List<TailscaleDevice>? tailscaleDevices,
    String? customUrl,
    ProviderInfo? selectedProvider,
    String? gatewayPassword,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      discoveredProviders: discoveredProviders ?? this.discoveredProviders,
      tailscaleDevices: tailscaleDevices ?? this.tailscaleDevices,
      customUrl: customUrl ?? this.customUrl,
      selectedProvider: selectedProvider ?? this.selectedProvider,
      gatewayPassword: gatewayPassword ?? this.gatewayPassword,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Service managing the setup wizard flow
class SetupWizardService extends ChangeNotifier {
  final ProviderDiscoveryService _discovery;
  final SetupStatusService _setupStatus;
  final ProviderConfigurationManager _configManager;

  WizardState _state = const WizardState();
  Timer? _testTimeoutTimer;
  bool _setupCompleted = false; // Track if setup was completed this session

  SetupWizardService(this._discovery, this._setupStatus, this._configManager);

  WizardState get state => _state;
  bool get isSetupCompleted => _setupCompleted;

  /// Initialize the wizard - check if first run
  Future<bool> shouldShowWizard() async {
    try {
      // If setup was just completed, don't show wizard again
      if (_setupCompleted) {
        debugPrint('[SetupWizard] Setup already completed this session');
        return false;
      }

      // Force wizard in test mode
      if (AppConfig.forceSetupWizard) {
        debugPrint('[SetupWizard] Force setup wizard enabled, showing wizard');
        return true;
      }

      // For now, always show wizard if no provider is configured
      final providers = await _configManager.getAllProviders();
      return providers.isEmpty;
    } catch (e) {
      debugPrint('[SetupWizard] Error checking wizard status: $e');
      return true; // Show wizard on error
    }
  }

  /// Set connection method
  void selectConnectionMethod(ConnectionMethod method) {
    _state = _state.copyWith(
      selectedMethod: method,
      errorMessage: null,
    );

    // If current step is beyond the new total, reset to step 1 (ConnectionMethodStep)
    // This can happen if user goes back and changes method after progressing
    final totalSteps = _getTotalSteps();
    if (_state.currentStep >= totalSteps) {
      _state = _state.copyWith(currentStep: 1);
    }

    notifyListeners();
  }

  /// Set custom URL
  void setCustomUrl(String url) {
    final trimmedUrl = url.trim();
    _state = _state.copyWith(
      customUrl: trimmedUrl,
      errorMessage: null,
    );

    // If we have a selected provider, update its URL to the custom one
    if (_state.selectedProvider != null) {
      final updatedProvider = ProviderInfo(
        id: _state.selectedProvider!.id,
        type: _state.selectedProvider!.type,
        name: _state.selectedProvider!.name,
        url: trimmedUrl,
        isLocal: _state.selectedProvider!.isLocal,
        isAvailable: _state.selectedProvider!.isAvailable,
      );
      _state = _state.copyWith(selectedProvider: updatedProvider);
    }

    notifyListeners();
  }

  /// Go to next step
  void nextStep() {
    final totalSteps = _getTotalSteps();
    if (_state.currentStep < totalSteps - 1) {
      _state = _state.copyWith(
        currentStep: _state.currentStep + 1,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Go to previous step
  void previousStep() {
    if (_state.currentStep > 0) {
      _state = _state.copyWith(
        currentStep: _state.currentStep - 1,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Jump to specific step
  void goToStep(int step) {
    if (step >= 0 && step < _getTotalSteps()) {
      _state = _state.copyWith(
        currentStep: step,
        errorMessage: null,
      );
      notifyListeners();
    }
  }

  /// Scan for local providers
  Future<void> scanForProviders() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final providers = await _discovery.scanForProviders();
      _state = _state.copyWith(
        discoveredProviders: providers,
        isLoading: false,
      );
      notifyListeners();

      // Auto-select OpenClaw if found
      final openclaw = providers.firstWhere(
        (p) => p.type == ProviderType.openclaw,
        orElse: () =>
            providers.isNotEmpty ? providers.first : _createDefaultProvider(),
      );
      _state = _state.copyWith(selectedProvider: openclaw);
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to scan for providers: $e',
      );
      notifyListeners();
    }
  }

  /// Discover Tailscale devices
  Future<void> discoverTailscaleDevices() async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final devices = await _discovery.discoverTailscaleDevices();
      _state = _state.copyWith(
        tailscaleDevices: devices,
        isLoading: false,
      );
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to discover Tailscale devices: $e',
      );
      notifyListeners();
    }
  }

  /// Test connection to provider
  Future<ConnectionTestResult?> testConnection(String url) async {
    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final result = await _discovery.testConnection(url);
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return result;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Connection test failed: $e',
      );
      notifyListeners();
      return null;
    }
  }

  /// Select a provider
  void selectProvider(ProviderInfo provider) {
    _state = _state.copyWith(
      selectedProvider: provider,
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Set OpenClaw Gateway password
  void setGatewayPassword(String password) {
    _state = _state.copyWith(
      gatewayPassword: password.trim(),
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Complete setup and save configuration
  Future<bool> completeSetup() async {
    if (_state.selectedProvider == null) {
      _state = _state.copyWith(errorMessage: 'No provider selected');
      notifyListeners();
      return false;
    }

    // Check if password is required for OpenClaw Gateway
    if (_state.selectedProvider!.type == ProviderType.openclaw &&
        (_state.gatewayPassword == null || _state.gatewayPassword!.isEmpty)) {
      _state = _state.copyWith(
          errorMessage: 'OpenClaw Gateway password is required');
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      // Use custom URL if provided, otherwise use provider's discovered URL
      final providerUrl = _state.customUrl ?? _state.selectedProvider!.url;

      // Save provider configuration
      await _configManager.saveProvider(
        name: _state.selectedProvider!.name,
        type: _state.selectedProvider!.type,
        url: providerUrl,
        isLocal: _state.selectedProvider!.isLocal,
        isDefault: true,
      );

      // Save gateway password to secure storage
      if (_state.gatewayPassword != null &&
          _state.gatewayPassword!.isNotEmpty) {
        debugPrint(
            '[SetupWizard] Saving gateway password to secure storage...');
        await _saveGatewayPassword(_state.gatewayPassword!);
        debugPrint('[SetupWizard] Gateway password saved successfully');
      } else {
        debugPrint(
            '[SetupWizard] WARNING: No valid gateway password to save (null or empty)');
        _state = _state.copyWith(
          isLoading: false,
          errorMessage:
              'Token is required. Please generate a token and paste it above.',
        );
        notifyListeners();
        return false;
      }

      // Mark setup as complete
      // Hardcoded local_user as auth service is not currently integrated in wizard
      final userId = 'local_user';
      await _setupStatus.markSetupComplete(userId);

      // Mark setup as completed in this session
      _setupCompleted = true;
      debugPrint('[SetupWizard] Setup completed successfully');

      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      return true;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to save configuration: $e',
      );
      notifyListeners();
      return false;
    }
  }

  /// Save gateway password to secure storage
  Future<void> _saveGatewayPassword(String password) async {
    try {
      final storage = const FlutterSecureStorage();
      // Use the same key as ConnectionManagerService._gatewayTokenKey
      await storage.write(key: 'openclaw_gateway_token', value: password);
      debugPrint('[SetupWizard] Saved gateway password to secure storage');
    } catch (e) {
      debugPrint('[SetupWizard] Failed to save gateway password: $e');
      rethrow;
    }
  }

  /// Clear error message
  void clearError() {
    _state = _state.copyWith(errorMessage: null);
    notifyListeners();
  }

  /// Reset wizard state
  void reset() {
    _state = const WizardState();
    notifyListeners();
  }

  int _getTotalSteps() {
    // Base steps: Welcome, Connection Method, Detection, Password, Test, Complete = 6
    // Optional: Tailscale (1), Remote (1)
    int steps = 6;
    if (_state.selectedMethod == ConnectionMethod.tailscale) {
      steps++; // TailscaleDiscoveryStep
    }
    if (_state.selectedMethod == ConnectionMethod.custom) {
      steps++; // RemoteConnectionStep
    }
    return steps;
  }

  ProviderInfo _createDefaultProvider() {
    return const ProviderInfo(
      id: 'openclaw_default',
      type: ProviderType.openclaw,
      name: 'OpenClaw Gateway',
      url: 'http://127.0.0.1:18789',
      isLocal: true,
      isAvailable: false,
    );
  }

  /// Auto-detect OpenClaw Gateway token from config file
  /// Returns the token if found, null otherwise
  Future<String?> autoDetectGatewayToken() async {
    if (kIsWeb) {
      debugPrint('[SetupWizard] Token auto-detection not available on web');
      return null;
    }

    try {
      // Try to find OpenClaw config file
      final homeDir =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (homeDir == null) {
        debugPrint('[SetupWizard] Could not determine home directory');
        return null;
      }

      final configFile = File('$homeDir/.openclaw/openclaw.json');
      if (!await configFile.exists()) {
        debugPrint(
            '[SetupWizard] OpenClaw config file not found at ${configFile.path}');
        return null;
      }

      final content = await configFile.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;

      // Navigate to gateway.auth.token
      final gateway = config['gateway'] as Map<String, dynamic>?;
      final auth = gateway?['auth'] as Map<String, dynamic>?;
      final token = auth?['token'] as String?;

      if (token != null && token.isNotEmpty) {
        debugPrint(
            '[SetupWizard] Found token in OpenClaw config: ${token.substring(0, token.length > 8 ? 8 : token.length)}...');
        return token;
      }

      debugPrint('[SetupWizard] No token found in OpenClaw config');
      return null;
    } catch (e) {
      debugPrint('[SetupWizard] Error detecting token: $e');
      return null;
    }
  }

  /// Get OpenClaw config file path for display
  String getOpenClawConfigPath() {
    if (kIsWeb) return '';
    final homeDir = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '~';
    return '$homeDir/.openclaw/openclaw.json';
  }

  /// Run openclaw CLI command to get token (fallback method)
  Future<String?> getTokenFromCli() async {
    if (kIsWeb) {
      debugPrint('[SetupWizard] CLI not available on web');
      return null;
    }

    try {
      final result = await Process.run(
        'openclaw',
        ['config', 'get', 'gateway.auth.token'],
      );

      if (result.exitCode == 0) {
        final token = (result.stdout as String).trim();
        if (token.isNotEmpty) {
          debugPrint(
              '[SetupWizard] Got token from CLI: ${token.substring(0, token.length > 8 ? 8 : token.length)}...');
          return token;
        }
      }

      debugPrint(
          '[SetupWizard] CLI returned non-zero exit code: ${result.exitCode}');
      debugPrint('[SetupWizard] stderr: ${result.stderr}');
      return null;
    } catch (e) {
      debugPrint('[SetupWizard] Error running openclaw CLI: $e');
      return null;
    }
  }

  /// Try multiple methods to auto-detect the gateway token
  Future<String?> detectGatewayToken() async {
    // Method 1: Try reading config file directly
    var token = await autoDetectGatewayToken();
    if (token != null && token.isNotEmpty) {
      return token;
    }

    // Method 2: Try CLI command
    token = await getTokenFromCli();
    if (token != null && token.isNotEmpty) {
      return token;
    }

    return null;
  }

  @override
  void dispose() {
    _testTimeoutTimer?.cancel();
    super.dispose();
  }
}
