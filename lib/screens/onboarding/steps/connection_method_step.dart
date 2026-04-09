import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/screens/onboarding/widgets/connection_method_card.dart';

/// Connection Method Selection Step
/// User selects how they connect to their backend
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
                'Choose your backend',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Select the backend you want to connect to',
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
                    icon: Icons.hub,
                    title: 'OpenClaw Gateway',
                    description: 'OpenClaw Gateway running locally or remote',
                    selected:
                        wizard.state.selectedMethod == ConnectionMethod.local ||
                        wizard.state.selectedMethod ==
                            ConnectionMethod.tailscale ||
                        wizard.state.selectedMethod ==
                            ConnectionMethod.custom,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.local),
                  ),
                  const SizedBox(height: 16),
                  ConnectionMethodCard(
                    icon: Icons.smart_toy,
                    title: 'Hermes Agent',
                    description:
                        'Hermes Agent running on this computer or remote',
                    selected:
                        wizard.state.selectedMethod == ConnectionMethod.hermes,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.hermes),
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
                        'Not sure? Choose "OpenClaw Gateway" if you\'re using the OpenClaw ecosystem.',
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
