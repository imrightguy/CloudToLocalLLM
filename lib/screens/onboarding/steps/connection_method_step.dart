import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/screens/onboarding/widgets/connection_method_card.dart';

/// Connection Method Selection Step
/// User selects how they connect to their agent runtime
class ConnectionMethodStep extends StatelessWidget {
  const ConnectionMethodStep({super.key});

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
                Icons.cable,
                size: 64,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Choose your agent runtime',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Select the runtime that will power the main channel',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Connection method cards
              Column(
                children: [
                  ConnectionMethodCard(
                    icon: Icons.smart_toy,
                    title: 'Hermes Agent',
                    description:
                        'First supported path for a local or private runtime',
                    selected:
                        wizard.state.selectedMethod == ConnectionMethod.hermes,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.hermes),
                  ),
                  const SizedBox(height: 16),
                  ConnectionMethodCard(
                    icon: Icons.hub,
                    title: 'OpenClaw or custom runtime',
                    description:
                        'OpenClaw Gateway, Tailscale device, or compatible private URL',
                    selected: wizard.state.selectedMethod ==
                            ConnectionMethod.local ||
                        wizard.state.selectedMethod ==
                            ConnectionMethod.tailscale ||
                        wizard.state.selectedMethod == ConnectionMethod.custom,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.local),
                  ),
                ],
              ),

              // Info box
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ollama and LM Studio can be added later in settings for memory and helper tasks.',
                        style: TextStyle(color: Colors.amber.shade900),
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
