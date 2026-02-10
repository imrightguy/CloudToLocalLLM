import 'package:flutter/material.dart';
import '../../services/provider_configuration_manager.dart';
import '../../di/locator.dart' as di;
import 'settings_category_widgets.dart';
import 'settings_input_widgets.dart';

class OpenClawGatewayCategory extends SettingsCategoryContentWidget {
  const OpenClawGatewayCategory({
    super.key,
    required super.categoryId,
    super.isActive = true,
    super.onSettingsChanged,
  });

  @override
  Widget buildCategoryContent(BuildContext context) {
    return const _OpenClawGatewayCategoryContent();
  }
}

class _OpenClawGatewayCategoryContent extends StatefulWidget {
  const _OpenClawGatewayCategoryContent();

  @override
  State<_OpenClawGatewayCategoryContent> createState() =>
      _OpenClawGatewayCategoryContentState();
}

class _OpenClawGatewayCategoryContentState
    extends State<_OpenClawGatewayCategoryContent> {
  late ProviderConfigurationManager _configManager;
  String _currentUrl = '';
  bool _isInitialized = false;
  bool _isSaving = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _configManager = di.serviceLocator.get<ProviderConfigurationManager>();
    _currentUrl = _configManager.getPreference<String>(
        'openclaw_gateway_url', 'http://127.0.0.1:18789');
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final url = _currentUrl.trim();
      if (url.isEmpty) throw 'URL cannot be empty';

      final uri = Uri.parse(url);
      if (!uri.hasScheme || !uri.hasAuthority) throw 'Invalid URL format';

      await _configManager.updatePreference('openclaw_gateway_url', url);

      if (mounted) {
        setState(() {
          _successMessage = 'Settings saved successfully';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_successMessage != null)
          SettingsSuccessMessage(message: _successMessage!),
        if (_errorMessage != null)
          SettingsValidationError(message: _errorMessage!),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gateway Connection',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Configure how the dashboard connects to your OpenClaw Gateway.'),
              const SizedBox(height: 24),
              SettingsTextInput(
                label: 'Gateway URL',
                description: 'The URL where your OpenClaw Gateway is reachable.',
                value: _currentUrl,
                onChanged: (value) {
                  setState(() {
                    _currentUrl = value;
                  });
                },
                hintText: 'http://127.0.0.1:18789',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Gateway Settings'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
