import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/screens/onboarding/widgets/connection_method_card.dart';

/// Connection Method Selection Step
/// User selects how they connect to OpenClaw Gateway
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
                'How will you connect to OpenClaw Gateway?',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Select the option that best describes your setup',
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
                    icon: Icons.computer,
                    title: 'Local on this computer',
                    description: 'OpenClaw Gateway running on this computer',
                    selected:
                        wizard.state.selectedMethod == ConnectionMethod.local,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.local),
                  ),
                  const SizedBox(height: 16),
                  ConnectionMethodCard(
                    icon: Icons.lan,
                    title: 'Remote via Tailscale',
                    description: 'OpenClaw Gateway on your tailnet or VPS',
                    selected: wizard.state.selectedMethod ==
                        ConnectionMethod.tailscale,
                    onTap: () => wizard
                        .selectConnectionMethod(ConnectionMethod.tailscale),
                  ),
                  const SizedBox(height: 16),
                  ConnectionMethodCard(
                    icon: Icons.link,
                    title: 'Custom remote URL',
                    description: 'SSH tunnel, VPN, or custom URL',
                    selected:
                        wizard.state.selectedMethod == ConnectionMethod.custom,
                    onTap: () =>
                        wizard.selectConnectionMethod(ConnectionMethod.custom),
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
                        'Not sure? Choose "Local" if OpenClaw is on this computer.',
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
