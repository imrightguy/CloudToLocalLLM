import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// OpenClaw Gateway Password Step
/// Collects the OpenClaw Gateway password/token for local connections
class GatewayPasswordStep extends StatefulWidget {
  const GatewayPasswordStep({super.key});

  @override
  State<GatewayPasswordStep> createState() => _GatewayPasswordStepState();
}

class _GatewayPasswordStepState extends State<GatewayPasswordStep> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = false; // Default to visible for tokens
  bool _isDetecting = false;
  String? _detectionMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.isNotEmpty) {
      setState(() {
        _passwordController.text = text;
        _detectionMessage = null;
      });
      // Need to get wizard from context since we're in a callback
      if (mounted) {
        context.read<SetupWizardService>().setGatewayPassword(text);
      }
    }
  }

  Future<void> _autoDetectToken() async {
    setState(() {
      _isDetecting = true;
      _detectionMessage = null;
    });

    final wizard = context.read<SetupWizardService>();
    final token = await wizard.detectGatewayToken();

    if (mounted) {
      setState(() {
        _isDetecting = false;
        if (token != null && token.isNotEmpty) {
          _passwordController.text = token;
          wizard.setGatewayPassword(token);
          _detectionMessage = 'Token detected from OpenClaw config!';
        } else {
          _detectionMessage =
              'Could not auto-detect token. Please enter it manually.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final provider = wizard.state.selectedProvider;

        // Only OpenClaw uses the gateway token step. Hermes/custom runtimes use
        // their own URL/test flow, and support providers are not runtime setup.
        if (provider == null || provider.type != ProviderType.openclaw) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            wizard.nextStep();
          });
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header
                Icon(
                  Icons.lock,
                  size: 64,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'OpenClaw Gateway Password',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your OpenClaw Gateway token to complete the setup.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Token input
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enableInteractiveSelection: true,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    wizard.setGatewayPassword(value);
                  },
                  decoration: InputDecoration(
                    labelText: 'Token',
                    prefixIcon: const Icon(Icons.key),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.paste),
                          tooltip: 'Paste from clipboard',
                          onPressed: _pasteFromClipboard,
                        ),
                        IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          tooltip:
                              _obscurePassword ? 'Show token' : 'Hide token',
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ],
                    ),
                    helperText:
                        'Get token: openclaw config get gateway.auth.token',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 1,
                ),
                const SizedBox(height: 24),

                // Auto-detect button (desktop only)
                if (!kIsWeb) ...[
                  ElevatedButton.icon(
                    onPressed: _isDetecting ? null : _autoDetectToken,
                    icon: _isDetecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(
                        _isDetecting ? 'Detecting...' : 'Auto-detect Token'),
                  ),
                  if (_detectionMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _detectionMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _detectionMessage!.contains('Could not')
                                ? Colors.orange
                                : Colors.green,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                ],

                // Password help section
                ExpansionTile(
                  title: const Text('How do I get my token?'),
                  initiallyExpanded: false,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHelpItem(
                            context,
                            'Option 1: Auto-detect (recommended)',
                            'Click "Auto-detect Token" above. The app will read the token from your OpenClaw config file at ~/.openclaw/openclaw.json',
                          ),
                          const SizedBox(height: 12),
                          _buildHelpItem(
                            context,
                            'Option 2: Get token via CLI',
                            'Run: openclaw config get gateway.auth.token\nCopy the output and paste it above.',
                          ),
                          const SizedBox(height: 12),
                          _buildHelpItem(
                            context,
                            'Option 3: Read config file directly',
                            'Open ~/.openclaw/openclaw.json and find gateway.auth.token',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Copy command button
                OutlinedButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      const ClipboardData(
                          text: 'openclaw config get gateway.auth.token'),
                    );
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Command copied! Paste in terminal'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.terminal),
                  label: const Text('Copy Command to Terminal'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpItem(
      BuildContext context, String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
      ],
    );
  }
}
