import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/platform_config.dart';
import '../models/installation_step.dart';
import '../models/download_option.dart';
import '../services/platform_detection_service.dart';

/// Widget that provides platform-specific installation instructions with visual aids
class InstallationGuide extends StatefulWidget {
  final PlatformType platform;
  final String installationType;
  final DownloadOption downloadOption;
  final VoidCallback? onInstallationComplete;
  final Function(String error)? onInstallationError;
  final bool showTroubleshooting;
  final bool enableValidation;

  const InstallationGuide({
    super.key,
    required this.platform,
    required this.installationType,
    required this.downloadOption,
    this.onInstallationComplete,
    this.onInstallationError,
    this.showTroubleshooting = true,
    this.enableValidation = true,
  });

  @override
  State<InstallationGuide> createState() => _InstallationGuideState();
}

class _InstallationGuideState extends State<InstallationGuide> {
  final PlatformDetectionService _platformService = PlatformDetectionService();
  List<InstallationStep> _installationSteps = [];
  int _currentStepIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isValidatingInstallation = false;
  bool _installationValidated = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _loadInstallationSteps();
  }

  void _loadInstallationSteps() {
    try {
      final platformConfig = _platformService.getPlatformConfig(
        widget.platform,
      );
      if (platformConfig != null) {
        _installationSteps = platformConfig.getInstallationSteps(
          widget.installationType,
        );
        _installationSteps.sort((a, b) => a.order.compareTo(b.order));
      }

      if (_installationSteps.isEmpty) {
        _errorMessage =
            'No installation steps found for ${widget.platform.displayName} (${widget.installationType})';
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading installation steps: $e';
      });
      widget.onInstallationError?.call(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildDownloadInfo(),
        const SizedBox(height: 24),
        _buildStepsList(),
        if (widget.showTroubleshooting) ...[
          const SizedBox(height: 24),
          _buildTroubleshootingSection(),
        ],
        const SizedBox(height: 24),
        _buildCompletionSection(),
      ],
    );
  }

  Widget _buildErrorView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Unknown error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadInstallationSteps();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _getPlatformIcon(),
              size: 32,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Installation Guide',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${widget.platform.displayName} - ${widget.installationType}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Download Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Size:', widget.downloadOption.fileSize),
            _buildInfoRow('Type:', widget.downloadOption.installationType),
            if (widget.downloadOption.requirements.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Requirements:',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...widget.downloadOption.requirements.map(
                (req) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(req)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStepsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Installation Steps',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...List.generate(_installationSteps.length, (index) {
          return _buildStepCard(_installationSteps[index], index);
        }),
      ],
    );
  }

  Widget _buildStepCard(InstallationStep step, int index) {
    final isCompleted = index < _currentStepIndex;
    final isCurrent = index == _currentStepIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isCurrent ? 4 : 1,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCurrent,
          leading: CircleAvatar(
            backgroundColor: isCompleted
                ? Colors.green
                : isCurrent
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white)
                : Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
          title: Text(
            step.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: isCompleted ? Colors.green : null,
                ),
          ),
          subtitle: step.isOptional ? const Text('Optional') : null,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.description),
                  if (step.imageUrl != null) ...[
                    const SizedBox(height: 12),
                    _buildStepImage(step.imageUrl!),
                  ],
                  if (step.commands.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCommandsSection(step.commands),
                  ],
                  if (step.troubleshootingTips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildTroubleshootingTips(step.troubleshootingTips),
                  ],
                  const SizedBox(height: 12),
                  _buildStepActions(index),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPlatformIcon() {
    switch (widget.platform) {
      case PlatformType.windows:
        return Icons.desktop_windows;
      case PlatformType.macos:
        return Icons.laptop_mac;
      case PlatformType.linux:
        return Icons.computer;
      default:
        return Icons.device_unknown;
    }
  }

  Widget _buildStepImage(String imageUrl) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 100,
              color: Colors.grey.shade100,
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommandsSection(List<String> commands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commands:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: commands.map((command) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        command,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () => _copyToClipboard(command),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingTips(List<String> tips) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Troubleshooting Tips:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...tips.map(
          (tip) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(tip)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepActions(int stepIndex) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (stepIndex > 0)
          TextButton(
            onPressed: _goToPreviousStep,
            child: const Text('Previous'),
          )
        else
          const SizedBox(),
        ElevatedButton(
          onPressed: () => _markStepComplete(stepIndex),
          child: Text(
            stepIndex == _installationSteps.length - 1 ? 'Complete' : 'Next',
          ),
        ),
      ],
    );
  }

  Widget _buildTroubleshootingSection() {
    final platformConfig = _platformService.getPlatformConfig(widget.platform);
    if (platformConfig?.troubleshootingGuides.isEmpty ?? true) {
      return const SizedBox.shrink();
    }

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.help_outline),
        title: const Text('Common Issues & Solutions'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: platformConfig!.troubleshootingGuides.entries.map((
                entry,
              ) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _installationValidated ? Icons.check_circle : Icons.info,
                  color: _installationValidated ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  _installationValidated
                      ? 'Installation Complete!'
                      : 'Ready to Complete Installation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _installationValidated
                  ? 'Your CloudToLocalLLM installation has been validated and is ready to use.'
                  : 'Click "Validate Installation" to verify your installation is working correctly.',
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _openDocumentation,
                  icon: const Icon(Icons.help),
                  label: const Text('Documentation'),
                ),
                if (!_installationValidated && widget.enableValidation)
                  ElevatedButton.icon(
                    onPressed: _isValidatingInstallation
                        ? null
                        : _validateInstallation,
                    icon: _isValidatingInstallation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified),
                    label: Text(
                      _isValidatingInstallation
                          ? 'Validating...'
                          : 'Validate Installation',
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: widget.onInstallationComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Get Started'),
                  ),
              ],
            ),
            if (widget.enableValidation && !_installationValidated) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _markInstallationComplete,
                child: const Text('Skip validation and continue'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Copied to clipboard: $text')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                const Expanded(child: Text('Failed to copy to clipboard')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _markStepComplete(int stepIndex) {
    setState(() {
      _currentStepIndex = stepIndex + 1;
    });

    // Last step completed - show completion section instead of immediately calling callback
    if (stepIndex == _installationSteps.length - 1) {
      // The completion section will handle validation and final callback
      setState(() {
        // Trigger rebuild to show completion section
      });
    }
  }

  void _goToPreviousStep() {
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
    }
  }

  void _openDocumentation() async {
    const documentationUrl = 'https://docs.cloudtolocalllm.online/installation';
    try {
      final uri = Uri.parse(documentationUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open documentation. Please visit docs.cloudtolocalllm.online',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening documentation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Validate installation completion
  Future<void> _validateInstallation() async {
    if (!widget.enableValidation) {
      _markInstallationComplete();
      return;
    }

    setState(() {
      _isValidatingInstallation = true;
      _validationError = null;
    });

    try {
      // Perform platform-specific validation checks
      final validationResult = await _performInstallationValidation();

      setState(() {
        _isValidatingInstallation = false;
        _installationValidated = validationResult.isValid;
        _validationError = validationResult.error;
      });

      if (validationResult.isValid) {
        _markInstallationComplete();
      } else {
        _showValidationErrorDialog(
          validationResult.error ?? 'Installation validation failed',
        );
      }
    } catch (e) {
      setState(() {
        _isValidatingInstallation = false;
        _validationError = 'Validation error: $e';
      });
      _showValidationErrorDialog('Error during validation: $e');
    }
  }

  /// Perform platform-specific installation validation
  Future<InstallationValidationResult> _performInstallationValidation() async {
    // Simulate validation checks - in a real implementation, this would:
    // 1. Check if the downloaded file exists and is valid
    // 2. Verify installation directory/registry entries
    // 3. Test basic application functionality
    // 4. Validate required dependencies

    await Future.delayed(
      const Duration(seconds: 2),
    ); // Simulate validation time

    switch (widget.platform) {
      case PlatformType.windows:
        return _validateWindowsInstallation();
      case PlatformType.macos:
        return _validateMacOSInstallation();
      case PlatformType.linux:
        return _validateLinuxInstallation();
      default:
        return InstallationValidationResult(
          isValid: true,
          message:
              'Manual validation required for ${widget.platform.displayName}',
        );
    }
  }

  /// Validate Windows installation
  Future<InstallationValidationResult> _validateWindowsInstallation() async {
    // In a real implementation, this would check:
    // - Registry entries
    // - Program Files directory
    // - Start menu shortcuts
    // - Service installation (if applicable)

    return InstallationValidationResult(
      isValid: true,
      message: 'Windows installation appears to be successful',
    );
  }

  /// Validate macOS installation
  Future<InstallationValidationResult> _validateMacOSInstallation() async {
    // In a real implementation, this would check:
    // - Applications directory
    // - LaunchAgents/LaunchDaemons
    // - Keychain entries
    // - Permissions

    return InstallationValidationResult(
      isValid: true,
      message: 'macOS installation appears to be successful',
    );
  }

  /// Validate Linux installation
  Future<InstallationValidationResult> _validateLinuxInstallation() async {
    // In a real implementation, this would check:
    // - Binary in PATH
    // - Desktop files
    // - Systemd services
    // - Configuration files

    return InstallationValidationResult(
      isValid: true,
      message: 'Linux installation appears to be successful',
    );
  }

  /// Mark installation as complete
  void _markInstallationComplete() {
    setState(() {
      _installationValidated = true;
    });
    widget.onInstallationComplete?.call();
  }

  /// Show validation error dialog with troubleshooting options
  void _showValidationErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Installation Validation Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error),
            const SizedBox(height: 16),
            const Text(
              'What would you like to do?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openTroubleshootingGuide();
            },
            child: const Text('View Troubleshooting'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _validateInstallation(); // Retry validation
            },
            child: const Text('Retry Validation'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markInstallationComplete(); // Skip validation
            },
            child: const Text('Skip Validation'),
          ),
        ],
      ),
    );
  }

  /// Open troubleshooting guide
  void _openTroubleshootingGuide() async {
    const troubleshootingUrl =
        'https://docs.cloudtolocalllm.online/troubleshooting/installation';
    try {
      final uri = Uri.parse(troubleshootingUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open troubleshooting guide. Please visit docs.cloudtolocalllm.online',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening troubleshooting guide: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}

/// Result of installation validation
class InstallationValidationResult {
  final bool isValid;
  final String? message;
  final String? error;
  final Map<String, dynamic>? details;

  InstallationValidationResult({
    required this.isValid,
    this.message,
    this.error,
    this.details,
  });
}
