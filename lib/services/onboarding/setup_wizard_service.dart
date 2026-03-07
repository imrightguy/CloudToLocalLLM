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

/// Connection method selection
enum ConnectionMethod {
  local,
  tailscale,
  custom,
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
    Object? customUrl = _unset,
    Object? selectedProvider = _unset,
    String? gatewayPassword,
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
    ProviderInfo? updatedProvider = _state.selectedProvider;
    String? updatedCustomUrl = _state.customUrl;

    if (method != ConnectionMethod.custom) {
      updatedCustomUrl = null;
      if (updatedProvider?.type == ProviderType.custom) {
        updatedProvider = null;
      }
    }

    _state = _state.copyWith(
      selectedMethod: method,
      selectedProvider: updatedProvider,
      customUrl: updatedCustomUrl,
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

      final openclaw = providers.firstWhere(
        (p) => p.type == ProviderType.openclaw,
        orElse: () =>
            providers.isNotEmpty ? providers.first : _createDefaultProvider(),
      );

      _state = _state.copyWith(
        discoveredProviders: providers,
        selectedProvider: openclaw,
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
      _state = _state.copyWith(isLoading: false);
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
      // Use custom URL if provided, otherwise use provider's discovered URL
      final customUrl = _state.customUrl?.trim();
      final providerUrl =
          (_shouldUseCustomUrl() && customUrl != null && customUrl.isNotEmpty)
              ? customUrl
              : _state.selectedProvider!.url;

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
    return ProviderInfo(
      id: 'openclaw_default',
      type: ProviderType.openclaw,
      name: 'OpenClaw Gateway',
      url: AppConfig.gatewayUrl,
      isLocal: true,
      isAvailable: false,
    );
  }

  String? _validateCompleteSetupInput() {
    if (_state.selectedProvider == null) {
      return 'Select a provider before completing setup.';
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
