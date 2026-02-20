import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloudtolocalllm/services/onboarding/setup_wizard_service.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/welcome_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/connection_method_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/local_detection_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/tailscale_discovery_step.dart';
import 'package:cloudtolocalllm/screens/onboarding/steps/remote_connection_step.dart';
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SetupWizardService>(
      builder: (context, wizard, child) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildProgressIndicator(wizard.state.currentStep),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) {
                      wizard.goToStep(index);
                    },
                    children: _buildSteps(),
                  ),
                ),
                _buildNavigationButtons(wizard),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator(int currentStep) {
    const totalSteps = 5;
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

  List<Widget> _buildSteps() {
    return [
      const WelcomeStep(),
      const ConnectionMethodStep(),
      const LocalDetectionStep(),
      const TailscaleDiscoveryStep(),
      const RemoteConnectionStep(),
      const ConnectionTestStep(),
      const CompletionStep(),
    ];
  }

  Widget _buildNavigationButtons(SetupWizardService wizard) {
    final currentStep = wizard.state.currentStep;
    final isFirstStep = currentStep == 0;
    final isLastStep = currentStep == _buildSteps().length - 1;

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
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: const Text('Back'),
              ),
            ),
          if (!isFirstStep) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: wizard.state.isLoading
                  ? null
                  : () {
                      if (isLastStep) {
                        // Complete setup - handled by CompletionStep
                        return;
                      }

                      wizard.nextStep();
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
              child: Text(
                isLastStep ? 'Complete' : 'Next',
                wizard.state.isLoading ? 'Loading...' : null,
              ]..removeWhere((e) => e == null),
            ),
          ),
        ],
      ),
    );
  }
}
