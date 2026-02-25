import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';

/// Remote Connection Step
/// User enters a custom URL for OpenClaw Gateway
class RemoteConnectionStep extends StatefulWidget {
  const RemoteConnectionStep({super.key});

  @override
  State<RemoteConnectionStep> createState() => _RemoteConnectionStepState();
}

class _RemoteConnectionStepState extends State<RemoteConnectionStep> {
  final TextEditingController _urlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = context.read<SetupWizardService>();
      // Pre-fill if user already entered a URL
      if (wizard.state.customUrl != null) {
        _urlController.text = wizard.state.customUrl!;
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Icon(
                Icons.link,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Enter OpenClaw Gateway URL',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text(
                'Enter the full URL to your OpenClaw Gateway',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // URL input form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Gateway URL',
                        hintText: 'http://192.168.1.100:18789',
                        prefixIcon: Icon(Icons.http),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a URL';
                        }
                        final url = Uri.tryParse(value);
                        if (url == null || !url.hasScheme) {
                          return 'Please enter a valid URL (e.g., http://192.168.1.100:18789)';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        wizard.setCustomUrl(value);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Connection type selector (optional enhancement)
                    DropdownButtonFormField<String>(
                      initialValue: 'direct',
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Connection Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'direct',
                          child: Text('Direct HTTP/HTTPS'),
                        ),
                        DropdownMenuItem(
                          value: 'ssh',
                          child: Text('SSH Tunnel'),
                        ),
                      ],
                      onChanged: (value) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Example URLs
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline,
                            color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Example URLs:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• http://192.168.1.100:18789\n'
                      '• http://100.x.y.z:18789 (Tailscale IP)\n'
                      '• https://your-domain.com',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
