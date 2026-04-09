import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/utils/logger.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/welcome_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/connection_method_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/local_detection_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/gateway_password_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/tailscale_discovery_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/remote_connection_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/hermes_url_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/connection_test_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/completion_step.dart';

/// Setup Wizard Screen
/// Guides new users through OpenClaw Gateway configuration
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _lastStep = 0;
  ConnectionMethod? _lastMethod;
  String? _lastErrorSnackbarMessage;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Get total steps based on connection method
  int _getTotalSteps(ConnectionMethod? method) {
    return _buildSteps(method).length;
  }

  /// Check if step list changed (method changed)
  bool _stepListChanged(ConnectionMethod? method) {
    return _lastMethod != method;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        final method = wizard.state.selectedMethod;
        final totalSteps = _getTotalSteps(method);
        final currentStep = wizard.state.currentStep;

        // Handle method change - need to rebuild PageView with correct initial page
        if (_stepListChanged(method)) {
          _lastMethod = method;
          _lastStep = currentStep;
          // Don't animate on method change, just jump to current step
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients && currentStep < totalSteps) {
              _pageController.jumpToPage(currentStep);
            }
          });
        }
        // Listen for step changes and animate page
        else if (currentStep != _lastStep) {
          _lastStep = currentStep;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients && currentStep < totalSteps) {
              _pageController.animateToPage(
                currentStep,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildProgressIndicator(currentStep, totalSteps),
                Expanded(
                  child: PageView(
                    key: ValueKey(
                        'pageview_$method'), // Rebuild when method changes
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      wizard.goToStep(index);
                    },
                    children: _buildSteps(method),
                  ),
                ),
                _buildNavigationButtons(wizard, totalSteps),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(int currentStep, int totalSteps) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: List.generate(
              totalSteps,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < totalSteps - 1 ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= currentStep
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Step ${currentStep + 1} of $totalSteps',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(ConnectionMethod? method) {
    // Hermes has a simplified flow: Welcome → Connection Method → Hermes URL → Connection Test → Completion
    if (method == ConnectionMethod.hermes) {
      return <Widget>[
        const WelcomeStep(),
        const ConnectionMethodStep(),
        const HermesUrlStep(),
        const ConnectionTestStep(),
        const CompletionStep(),
      ];
    }

    // OpenClaw flow
    final steps = <Widget>[
      const WelcomeStep(), // 0 - Always shown
      const ConnectionMethodStep(), // 1 - Always shown
      const LocalDetectionStep(), // 2 - Always shown
      const GatewayPasswordStep(), // 3 - Always shown
    ];

    // Step 4: TailscaleDiscoveryStep - only for tailscale method
    if (method == ConnectionMethod.tailscale) {
      steps.add(const TailscaleDiscoveryStep());
    }

    // Step 5: RemoteConnectionStep - only for custom method
    if (method == ConnectionMethod.custom) {
      steps.add(const RemoteConnectionStep());
    }

    // Remaining steps - always shown
    steps.addAll([
      const ConnectionTestStep(),
      const CompletionStep(),
    ]);

    return steps;
  }

  void _showCompletionError(String message) {
    if (!mounted) return;

    if (_lastErrorSnackbarMessage == message) {
      return;
    }

    _lastErrorSnackbarMessage = message;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildNavigationButtons(SetupWizardService wizard, int totalSteps) {
    final currentStep = wizard.state.currentStep;
    final isFirstStep = currentStep == 0;
    final isLastStep = currentStep == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Row(
        children: [
          if (!isFirstStep)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  wizard.previousStep();
                  // PageController animation handled by state change listener in build()
                },
                child: const Text('Back'),
              ),
            ),
          if (!isFirstStep) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: wizard.state.isLoading
                  ? null
                  : () async {
                      if (isLastStep) {
                        _lastErrorSnackbarMessage = null;
                        final success = await wizard.completeSetup();

                        if (!success) {
                          final message = wizard.state.errorMessage ??
                              'Setup could not be completed right now. Please try again.';
                          _showCompletionError(message);
                          appLogger.warning(
                            '[SetupWizard] Setup completion failed at final step: $message',
                          );
                          return;
                        }

                        _lastErrorSnackbarMessage = null;

                        // Navigate to home on success
                        if (mounted) {
                          context.go('/');
                        }
                        return;
                      }

                      wizard.nextStep();
                      // PageController animation handled by state change listener in build()
                    },
              child: Text(
                isLastStep
                    ? 'Complete'
                    : wizard.state.isLoading
                        ? 'Loading...'
                        : 'Next',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
