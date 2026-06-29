import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloudtolocalllm/config/app_config.dart';
import 'package:cloudtolocalllm/utils/logger.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';
import 'package:cloudtolocalllm/services/settings_preference_service.dart';

/// Connection method selection
enum ConnectionMethod {
  local,
  tailscale,
  custom,
  hermes,
}

/// Setup wizard state
class WizardState {
  static const Object _unset = Object();

  final int currentStep;
  final ConnectionMethod? selectedMethod;
  final List<ProviderInfo> discoveredProviders;
  final List<TailscaleDevice> tailscaleDevices;
  final String? customUrl;
  final ProviderInfo? selectedProvider;
  final String? gatewayPassword; // OpenClaw Gateway password/token
  final String? hermesUrl; // Hermes Agent URL
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
    this.hermesUrl,
    this.isLoading = false,
    this.errorMessage,
  });

  WizardState copyWith({
    int? currentStep,
    ConnectionMethod? selectedMethod,
    List<ProviderInfo>? discoveredProviders,
    List<TailscaleDevice>? tailscaleDevices,
    Object? customUrl = _unset,
    Object? selectedProvider = _unset,
    String? gatewayPassword,
    Object? hermesUrl = _unset,
    bool? isLoading,
    Object? errorMessage = _unset,
  }) {
    return WizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedMethod: selectedMethod ?? this.selectedMethod,
      discoveredProviders: discoveredProviders ?? this.discoveredProviders,
      tailscaleDevices: tailscaleDevices ?? this.tailscaleDevices,
      customUrl:
          identical(customUrl, _unset) ? this.customUrl : customUrl as String?,
      selectedProvider: identical(selectedProvider, _unset)
          ? this.selectedProvider
          : selectedProvider as ProviderInfo?,
      gatewayPassword: gatewayPassword ?? this.gatewayPassword,
      hermesUrl:
          identical(hermesUrl, _unset) ? this.hermesUrl : hermesUrl as String?,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

enum _WizardOperation {
  providerScan,
  tailscaleDiscovery,
  connectionTest,
  completeSetup,
}

/// Service managing the setup wizard flow
class SetupWizardService extends ChangeNotifier {
  final ProviderDiscoveryService _discovery;
  final SetupStatusService _setupStatus;
  final ProviderConfigurationManager _configManager;
  final SettingsPreferenceService? _settings;

  WizardState _state = const WizardState();
  Timer? _testTimeoutTimer;
  bool _setupCompleted = false; // Track if setup was completed this session

  SetupWizardService(
    this._discovery,
    this._setupStatus,
    this._configManager, {
    SettingsPreferenceService? settings,
  }) : _settings = settings;

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

      final runtimes = await _configManager.getAllAgentRuntimes();
      return runtimes.isEmpty;
    } catch (e) {
      debugPrint('[SetupWizard] Error checking wizard status: $e');
      return true; // Show wizard on error
    }
  }

  /// Set connection method
  void selectConnectionMethod(ConnectionMethod method) {
    ProviderInfo? updatedProvider = _state.selectedProvider;
    String? updatedCustomUrl = _state.customUrl;
    String? updatedHermesUrl = _state.hermesUrl;

    if (method != ConnectionMethod.custom) {
      updatedCustomUrl = null;
      if (updatedProvider?.type == ProviderType.custom) {
        updatedProvider = null;
      }
    }

    if (method != ConnectionMethod.hermes) {
      updatedHermesUrl = null;
      if (updatedProvider?.type == ProviderType.hermes) {
        updatedProvider = null;
      }
    }

    _state = _state.copyWith(
      selectedMethod: method,
      selectedProvider: updatedProvider,
      customUrl: updatedCustomUrl,
      hermesUrl: updatedHermesUrl,
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
      var providers = await _discovery.scanForAgentRuntimes();

      // Fallback: if discovery returns empty, try a direct health check
      // against the default Hermes URL. This catches cases where the
      // discovery scan timed out or missed the running Hermes instance.
      if (providers.isEmpty) {
        debugPrint(
            '[SetupWizard] No providers discovered, trying direct health check...');
        final result =
            await _discovery.testConnection(AppConfig.defaultHermesUrl);
        if (result.isConnected) {
          debugPrint(
              '[SetupWizard] Direct health check succeeded — adding Hermes as discovered');
          providers = [
            ProviderInfo(
              id: 'hermes_fallback',
              type: ProviderType.hermes,
              name: 'Hermes Agent',
              url: AppConfig.defaultHermesUrl,
              isLocal: true,
              isAvailable: true,
              role: ProviderRole.agentRuntime,
            ),
          ];
        }
      }

      final selectedRuntime = _selectPreferredRuntime(providers);

      _state = _state.copyWith(
        discoveredProviders: providers,
        selectedProvider: selectedRuntime,
        isLoading: false,
        errorMessage: null,
      );
      notifyListeners();

      appLogger.info(
        '[SetupWizard] Provider scan completed with ${providers.length} providers',
      );
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Provider scan failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.providerScan),
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
        errorMessage: null,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Tailscale discovery failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.tailscaleDiscovery),
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
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: result.isConnected
            ? null
            : _mapUserSafeError(_WizardOperation.connectionTest),
      );
      notifyListeners();
      return result;
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Connection test failed for $url',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.connectionTest),
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

  /// Set Hermes Agent URL
  void setHermesUrl(String url) {
    final trimmedUrl = url.trim();
    _state = _state.copyWith(
      hermesUrl: trimmedUrl,
      errorMessage: null,
    );

    // Create/update a Hermes ProviderInfo from the URL
    final hermesProvider = ProviderInfo(
      id: 'hermes_wizard',
      type: ProviderType.hermes,
      name: 'Hermes Agent',
      url: trimmedUrl.isNotEmpty ? trimmedUrl : AppConfig.defaultHermesUrl,
      isLocal: true,
      isAvailable: false,
      role: ProviderRole.agentRuntime,
    );
    _state = _state.copyWith(selectedProvider: hermesProvider);

    notifyListeners();
  }

  /// Complete setup and save configuration
  Future<bool> completeSetup() async {
    final validationError = _validateCompleteSetupInput();
    if (validationError != null) {
      _state = _state.copyWith(isLoading: false, errorMessage: validationError);
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isLoading: true, errorMessage: null);
    notifyListeners();

    try {
      final method = _state.selectedMethod;
      // Use custom URL if provided, otherwise use provider's discovered URL
      final customUrl = _state.customUrl?.trim();
      final hermesUrl = _state.hermesUrl?.trim();
      final providerUrl = (method == ConnectionMethod.hermes &&
              hermesUrl != null &&
              hermesUrl.isNotEmpty)
          ? hermesUrl
          : (_shouldUseCustomUrl() && customUrl != null && customUrl.isNotEmpty)
              ? customUrl
              : _state.selectedProvider!.url;

      // Save provider configuration
      await _configManager.saveProvider(
        name: _state.selectedProvider!.name,
        type: _state.selectedProvider!.type,
        url: providerUrl,
        isLocal: _state.selectedProvider!.isLocal,
        isDefault: true,
        role: ProviderRole.agentRuntime,
      );

      await _persistRuntimeSelection(providerUrl);

      // Save gateway password to secure storage
      if (_state.selectedProvider!.type == ProviderType.openclaw &&
          _state.gatewayPassword != null &&
          _state.gatewayPassword!.isNotEmpty) {
        await _saveGatewayPassword(_state.gatewayPassword!);
      }

      // Mark setup as complete
      // Hardcoded local_user as auth service is not currently integrated in wizard
      final userId = 'local_user';
      await _setupStatus.markSetupComplete(userId);

      // Mark setup as completed in this session
      _setupCompleted = true;
      appLogger.info('[SetupWizard] Setup completed successfully');

      _state = _state.copyWith(isLoading: false, errorMessage: null);
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Setup completion failed',
        error: e,
        stackTrace: stackTrace,
      );
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: _mapUserSafeError(_WizardOperation.completeSetup),
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
      appLogger.info('[SetupWizard] Saved gateway password to secure storage');
    } catch (e, stackTrace) {
      appLogger.error(
        '[SetupWizard] Failed to save gateway password',
        error: e,
        stackTrace: stackTrace,
      );
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
    // Hermes flow: Welcome, Connection Method, Hermes URL, Test, Complete = 5
    if (_state.selectedMethod == ConnectionMethod.hermes) {
      return 5;
    }

    // OpenClaw steps: Welcome, Connection Method, Detection, Password, Test, Complete = 6
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

  ProviderInfo? _selectPreferredRuntime(List<ProviderInfo> providers) {
    if (providers.isEmpty) {
      return null;
    }

    for (final type in [
      ProviderType.hermes,
      ProviderType.openclaw,
      ProviderType.custom,
    ]) {
      final matches = providers.where((provider) => provider.type == type);
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }

    return providers.firstWhere(
      (provider) => provider.canServeAsAgentRuntime,
      orElse: () => providers.first,
    );
  }

  String? _validateCompleteSetupInput() {
    if (_state.selectedProvider == null) {
      return 'Select an agent runtime before completing setup.';
    }

    if (!_state.selectedProvider!.canServeAsAgentRuntime) {
      return 'Ollama, LM Studio, and raw model providers are support model providers. Select Hermes, OpenClaw, or a compatible agent runtime to complete setup.';
    }

    // Hermes-specific validation
    if (_state.selectedMethod == ConnectionMethod.hermes) {
      if (_state.selectedProvider!.type != ProviderType.hermes) {
        return 'Select a Hermes Agent runtime to complete Hermes setup.';
      }
      final hermesUrl = _state.hermesUrl?.trim() ?? '';
      if (hermesUrl.isEmpty) {
        return 'Enter a Hermes Agent URL.';
      }
      final uri = Uri.tryParse(hermesUrl);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty) {
        return 'Enter a valid Hermes URL that starts with http:// or https://.';
      }
      return null;
    }

    if (_shouldUseCustomUrl()) {
      final requireCustomUrl = _state.selectedMethod == ConnectionMethod.custom;
      final customUrlValidationError = _validateCustomUrl(
        _state.customUrl,
        requireValue: requireCustomUrl,
      );
      if (customUrlValidationError != null) {
        return customUrlValidationError;
      }
    }

    final password = _state.gatewayPassword?.trim() ?? '';
    if (_state.selectedProvider!.type == ProviderType.openclaw &&
        password.isEmpty) {
      return 'OpenClaw Gateway password is required.';
    }

    return null;
  }

  Future<void> _persistRuntimeSelection(String runtimeUrl) async {
    final settings = _settings;
    if (settings == null) {
      return;
    }

    switch (_state.selectedProvider!.type) {
      case ProviderType.hermes:
        await settings.setHermesEnabled(true);
        await settings.setHermesUrl(runtimeUrl);
        await settings.setActiveBackend(BackendType.hermes);

        // Persist the API key — try SharedPreferences first, then .env fallback
        var apiKey = await settings.getHermesApiKey();
        if (apiKey != null && apiKey.isNotEmpty) {
          await settings.setHermesApiKey(apiKey);
        }
        break;
      case ProviderType.openclaw:
        await settings.setHermesEnabled(false);
        await settings.setActiveBackend(BackendType.openclaw);
        break;
      case ProviderType.custom:
        await settings.setActiveBackend(null);
        break;
      case ProviderType.ollama:
      case ProviderType.lmStudio:
      case ProviderType.openAICompatible:
        break;
    }
  }

  bool _shouldUseCustomUrl() {
    final selectedMethod = _state.selectedMethod;
    if (selectedMethod != null) {
      return selectedMethod == ConnectionMethod.custom;
    }

    return _state.selectedProvider?.type == ProviderType.custom;
  }

  String? _validateCustomUrl(String? url, {bool requireValue = false}) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      if (requireValue) {
        return 'Enter a valid custom URL that starts with http:// or https://.';
      }
      return null;
    }

    final uri = Uri.tryParse(trimmed);
    final hasValidScheme = uri?.scheme == 'http' || uri?.scheme == 'https';
    final hasHost = uri?.host.isNotEmpty == true;

    if (uri == null || !hasValidScheme || !hasHost) {
      return 'Enter a valid custom URL that starts with http:// or https://.';
    }

    return null;
  }

  String _mapUserSafeError(_WizardOperation operation) {
    switch (operation) {
      case _WizardOperation.providerScan:
        return 'Could not scan for providers. Make sure local services are running and try again.';
      case _WizardOperation.tailscaleDiscovery:
        return 'Could not discover Tailscale devices. Make sure Tailscale is running and authenticated, then try again.';
      case _WizardOperation.connectionTest:
        return 'Connection test failed. Verify your connection settings and try again.';
      case _WizardOperation.completeSetup:
        return 'Setup could not be completed right now. Please verify your settings and try again.';
    }
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
      final homeDir = _getHomeDirectory();
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
    final homeDir = _getHomeDirectory() ?? '~';
    return '$homeDir/.openclaw/openclaw.json';
  }

  String? _getHomeDirectory() {
    if (kIsWeb) {
      return null;
    }

    try {
      return Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
    } catch (e) {
      debugPrint('[SetupWizard] Failed to read environment: $e');
      return null;
    }
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
