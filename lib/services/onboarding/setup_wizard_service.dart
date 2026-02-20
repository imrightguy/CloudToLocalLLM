import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/services/setup_status_service.dart';
import 'package:cloudtolocalllm/services/provider_configuration_manager.dart';

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
  final bool isLoading;
  final String? errorMessage;

  const WizardState({
    this.currentStep = 0,
    this.selectedMethod,
    this.discoveredProviders = const [],
    this.tailscaleDevices = const [],
    this.customUrl,
    this.selectedProvider,
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

  SetupWizardService(this._discovery, this._setupStatus, this._configManager);

  WizardState get state => _state;

  /// Initialize the wizard - check if first run
  Future<bool> shouldShowWizard() async {
    try {
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
    notifyListeners();
  }

  /// Set custom URL
  void setCustomUrl(String url) {
    _state = _state.copyWith(
      customUrl: url.trim(),
      errorMessage: null,
    );
    notifyListeners();
  }

  /// Go to next step
  void nextStep() {
    if (_state.currentStep < _getTotalSteps() - 1) {
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
        orElse: () => providers.isNotEmpty ? providers.first : _createDefaultProvider(),
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

  /// Complete setup and save configuration
  Future<bool> completeSetup() async {
    if (_state.selectedProvider == null) {
      _state = _state.copyWith(errorMessage: 'No provider selected');
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      // Save provider configuration
      await _configManager.saveProvider(
        name: _state.selectedProvider!.name,
        type: _state.selectedProvider!.type,
        url: _state.selectedProvider!.url,
        isLocal: _state.selectedProvider!.isLocal,
        isDefault: true,
      );

      // Mark setup as complete
      final userId = 'local_user'; // TODO: Get actual user ID
      await _setupStatus.markSetupComplete(userId);

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
    // Welcome, Connection Method, Detection/Config, Test, Complete
    return 5;
  }

  ProviderInfo _createDefaultProvider() {
    return ProviderInfo(
      type: ProviderType.openclaw,
      name: 'OpenClaw Gateway',
      url: 'http://127.0.0.1:18789',
      isLocal: true,
      isAvailable: false,
    );
  }

  @override
  void dispose() {
    _testTimeoutTimer?.cancel();
    super.dispose();
  }
}
