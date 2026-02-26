import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/services/provider_discovery_service.dart';
import 'package:cloudtolocalllm/models/provider_configuration.dart';

/// Tailscale Device Discovery Step
/// Discovers and lists Tailscale devices on the tailnet
class TailscaleDiscoveryStep extends StatefulWidget {
  const TailscaleDiscoveryStep({super.key});

  @override
  State<TailscaleDiscoveryStep> createState() => _TailscaleDiscoveryStepState();
}

class _TailscaleDiscoveryStepState extends State<TailscaleDiscoveryStep> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wizard = context.read<SetupWizardService>();
      debugPrint(
          '[TailscaleDiscoveryStep] initState - selectedMethod: ${wizard.state.selectedMethod}');

      // Only discover if this step is actually shown (tailscale method selected)
      if (wizard.state.selectedMethod == ConnectionMethod.tailscale) {
        debugPrint('[TailscaleDiscoveryStep] Starting Tailscale discovery');
        wizard.discoverTailscaleDevices();
      } else {
        debugPrint(
            '[TailscaleDiscoveryStep] Skipping discovery - method is ${wizard.state.selectedMethod}');
      }
    });
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
              if (wizard.state.isLoading) ...[
                const SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Discovering Tailscale devices...',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Scanning your tailnet',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ] else if (wizard.state.tailscaleDevices.isEmpty) ...[
                _buildNoDevices(context, wizard),
              ] else ...[
                _buildDeviceList(context, wizard),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoDevices(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Icon(
          Icons.lan,
          size: 64,
          color: Colors.orange.shade700,
        ),
        const SizedBox(height: 24),
        Text(
          'No Tailscale Devices Found',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Make sure Tailscale is installed and logged in.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => wizard.discoverTailscaleDevices(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => wizard.previousStep(),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Choose different connection method'),
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, SetupWizardService wizard) {
    return Column(
      children: [
        Icon(
          Icons.lan,
          size: 64,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 24),
        Text(
          'Select your OpenClaw Gateway device',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Found ${wizard.state.tailscaleDevices.length} device(s) on your tailnet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: wizard.state.tailscaleDevices.length,
            itemBuilder: (context, index) {
              final device = wizard.state.tailscaleDevices[index];
              return _buildDeviceCard(context, device, wizard);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(
      BuildContext context, TailscaleDevice device, SetupWizardService wizard) {
    final isSelected =
        wizard.state.selectedProvider?.url.contains(device.primaryIP ?? '') ??
            false;

    return InkWell(
      onTap: () {
        wizard.selectProvider(ProviderInfo(
          id: 'tailscale_${device.name.toLowerCase().replaceAll(' ', '_')}',
          type: ProviderType.openclaw,
          name: device.name,
          url: 'http://${device.primaryIP}:18789',
          isLocal: false,
          isAvailable: device.isOnline,
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: device.isOnline
                    ? Colors.green.shade100
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.computer,
                color: device.isOnline
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device.primaryIP ?? 'No IP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: Colors.grey.shade600,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).primaryColor,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? Colors.green.shade100
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  device.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: device.isOnline
                        ? Colors.green.shade900
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
