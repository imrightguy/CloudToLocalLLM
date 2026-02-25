import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/avatar/avatar_state_service.dart';
import '../../models/avatar/personality_models.dart';
import '../../di/locator.dart' as di;
import 'package:go_router/go_router.dart';
import 'achievements_screen.dart';

/// Avatar Settings Screen
///
/// Allows users to customize their avatar's personality, name,
/// and manage evolution stages.
class AvatarSettingsScreen extends StatefulWidget {
  const AvatarSettingsScreen({super.key});

  @override
  State<AvatarSettingsScreen> createState() => _AvatarSettingsScreenState();
}

class _AvatarSettingsScreenState extends State<AvatarSettingsScreen> {
  late AvatarStateService _avatarStateService;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Form state
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late double _formality;
  late double _humor;
  late double _enthusiasm;
  late double _empathy;

  // Evolution state
  String _selectedEvolutionStage = 'curious_explorer';
  final TextEditingController _evolutionReasonController =
      TextEditingController();
  bool _isRequestingEvolution = false;
  Map<String, dynamic>? _evolutionRequirements;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  /// Initialize avatar state service
  Future<void> _initializeService() async {
    try {
      _avatarStateService = di.serviceLocator.get<AvatarStateService>();

      // Listen to service changes
      _avatarStateService.addListener(_onAvatarStateChanged);

      // Load initial profile
      await _avatarStateService.loadProfile();

      // Initialize form state from current profile
      _initializeFormState();

      // Load evolution requirements
      await _loadEvolutionRequirements();

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _errorMessage = 'Failed to initialize avatar service: $e';
      });
      debugPrint('Error initializing avatar state service: $e');
    }
  }

  /// Initialize form fields from current profile
  void _initializeFormState() {
    final profile = _avatarStateService.currentProfile;
    if (profile != null) {
      _nameController = TextEditingController(text: profile.agentName);
      _formality = profile.traits.formality;
      _humor = profile.traits.humor;
      _enthusiasm = profile.traits.enthusiasm;
      _empathy = profile.traits.empathy;
      _selectedEvolutionStage = profile.evolutionStage;
    } else {
      // Default values
      _nameController = TextEditingController(text: 'CloudToLocalLLM');
      _formality = PersonalityTraits.defaultTraits.formality;
      _humor = PersonalityTraits.defaultTraits.humor;
      _enthusiasm = PersonalityTraits.defaultTraits.enthusiasm;
      _empathy = PersonalityTraits.defaultTraits.empathy;
    }
  }

  /// Load evolution requirements
  Future<void> _loadEvolutionRequirements() async {
    try {
      final requirements = await _avatarStateService.getEvolutionRequirements();
      setState(() {
        _evolutionRequirements = requirements;
      });
    } catch (e) {
      debugPrint('Error loading evolution requirements: $e');
    }
  }

  /// Handle avatar state changes
  void _onAvatarStateChanged() {
    if (mounted) {
      final profile = _avatarStateService.currentProfile;
      if (profile != null) {
        setState(() {
          _nameController.text = profile.agentName;
          _formality = profile.traits.formality;
          _humor = profile.traits.humor;
          _enthusiasm = profile.traits.enthusiasm;
          _empathy = profile.traits.empathy;
          _selectedEvolutionStage = profile.evolutionStage;
        });
      }

      if (_avatarStateService.error != null) {
        setState(() {
          _errorMessage = _avatarStateService.error;
        });
      }
    }
  }

  /// Save avatar settings
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      // Update agent name if changed
      if (_avatarStateService.agentName != _nameController.text) {
        await _avatarStateService.updateAgentName(_nameController.text);
      }

      // Update personality traits
      final traits = PersonalityTraits(
        formality: _formality,
        humor: _humor,
        enthusiasm: _enthusiasm,
        empathy: _empathy,
      );
      await _avatarStateService.updateTraits(traits);

      setState(() {
        _isLoading = false;
        _successMessage = 'Avatar settings saved successfully';
        _errorMessage = null;
      });

      // Clear success message after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save settings: $e';
      });
    }
  }

  /// Request evolution to selected stage
  Future<void> _requestEvolution() async {
    final reason = _evolutionReasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Please provide a reason for evolution';
      });
      return;
    }

    setState(() {
      _isRequestingEvolution = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final decision = await _avatarStateService.requestEvolution(
          _selectedEvolutionStage, reason);

      setState(() {
        _isRequestingEvolution = false;
      });

      if (decision.approved) {
        setState(() {
          _successMessage =
              'Evolution to ${decision.newStage} approved! Your avatar has evolved.';
          _errorMessage = null;
        });

        // Reload requirements after evolution
        await _loadEvolutionRequirements();

        // Clear success message after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _successMessage = null;
            });
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Evolution request denied: ${decision.reason}';
        });
      }

      // Clear reason field
      _evolutionReasonController.clear();
    } catch (e) {
      setState(() {
        _isRequestingEvolution = false;
        _errorMessage = 'Failed to request evolution: $e';
      });
    }
  }

  @override
  void dispose() {
    _avatarStateService.removeListener(_onAvatarStateChanged);
    _nameController.dispose();
    _evolutionReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Avatar Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider<AvatarStateService>.value(
      value: _avatarStateService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Avatar Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            tooltip: 'Back',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status messages
                if (_errorMessage != null) _buildErrorMessage(_errorMessage!),
                if (_successMessage != null)
                  _buildSuccessMessage(_successMessage!),

                // Current status card
                _buildStatusCard(),

                const SizedBox(height: 24),

                // Agent name section
                _buildAgentNameSection(),

                const SizedBox(height: 24),

                // Personality traits section
                _buildPersonalityTraitsSection(),

                const SizedBox(height: 24),

                // Visual customization section
                _buildVisualCustomizationSection(),

                const SizedBox(height: 24),

                // Achievements section
                _buildAchievementsSection(),

                const SizedBox(height: 24),

                // Evolution section
                _buildEvolutionSection(),

                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSettings,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Settings'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build error message widget
  Widget _buildErrorMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Build success message widget
  Widget _buildSuccessMessage(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// Build current status card
  Widget _buildStatusCard() {
    return Consumer<AvatarStateService>(
      builder: (context, avatarState, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.smart_toy,
                      color: Theme.of(context).colorScheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            avatarState.agentName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Stage: ${avatarState.evolutionStage}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.chat_bubble_outline,
                        label: 'Conversations',
                        value: avatarState.conversationCount.toString(),
                      ),
                    ),
                    Expanded(
                      child: _buildStatusItem(
                        icon: Icons.insights,
                        label: 'Depth Score',
                        value:
                            (avatarState.depthScore * 100).toStringAsFixed(0),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build status item widget
  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon,
            size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  /// Build agent name section
  Widget _buildAgentNameSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Agent Name',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Enter agent name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an agent name';
                }
                if (value.trim().length < 2) {
                  return 'Name must be at least 2 characters';
                }
                if (value.trim().length > 50) {
                  return 'Name must be less than 50 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'This name will be used to address your avatar in conversations.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build personality traits section
  Widget _buildPersonalityTraitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personality Traits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Adjust these sliders to customize your avatar\'s personality.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: 'Formality',
              value: _formality,
              onChanged: (value) => setState(() => _formality = value),
              icon: Icons.business_center,
              description: 'How formal the avatar communicates',
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: 'Humor',
              value: _humor,
              onChanged: (value) => setState(() => _humor = value),
              icon: Icons.sentiment_very_satisfied,
              description: 'Frequency and intensity of humor',
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: 'Enthusiasm',
              value: _enthusiasm,
              onChanged: (value) => setState(() => _enthusiasm = value),
              icon: Icons.emoji_emotions,
              description: 'Energy and excitement levels',
            ),
            const SizedBox(height: 16),
            _buildTraitSlider(
              label: 'Empathy',
              value: _empathy,
              onChanged: (value) => setState(() => _empathy = value),
              icon: Icons.favorite,
              description: 'Emotional understanding and support',
            ),
          ],
        ),
      ),
    );
  }

  /// Build trait slider widget
  Widget _buildTraitSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              (value * 100).toStringAsFixed(0),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Theme.of(context).colorScheme.primary,
            inactiveTrackColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            thumbColor: Theme.of(context).colorScheme.primary,
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            label: (value * 100).toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        Text(
          description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  /// Build visual customization section
  Widget _buildVisualCustomizationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Visual Customization',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Customize your avatar\'s visual appearance, including type, color, size, and effects.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.pushNamed('avatar-customization'),
                icon: const Icon(Icons.brush),
                label: const Text('Customize Visual Appearance'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build achievements section
  Widget _buildAchievementsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Achievements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'View your unlocked achievements and track your progress.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AchievementsScreen(),
                  ),
                ),
                icon: const Icon(Icons.emoji_events),
                label: const Text('View Achievements'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build evolution section
  Widget _buildEvolutionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Evolution',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Evolve your avatar to unlock new personality capabilities.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),

            // Current stage
            Consumer<AvatarStateService>(
              builder: (context, avatarState, child) {
                return Row(
                  children: [
                    Text('Current Stage: '),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(avatarState.evolutionStage),
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // Evolution requirements
            if (_evolutionRequirements != null) _buildEvolutionRequirements(),

            const SizedBox(height: 16),

            // Evolution request form
            DropdownButtonFormField<String>(
              initialValue: _selectedEvolutionStage,
              decoration: const InputDecoration(
                labelText: 'Evolve to Stage',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'curious_explorer',
                  child: Text('Curious Explorer (Initial)'),
                ),
                DropdownMenuItem(
                  value: 'knowledge_seeker',
                  child: Text('Knowledge Seeker'),
                ),
                DropdownMenuItem(
                  value: 'wise_companion',
                  child: Text('Wise Companion'),
                ),
                DropdownMenuItem(
                  value: 'enlightened_guide',
                  child: Text('Enlightened Guide'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedEvolutionStage = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _evolutionReasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for Evolution',
                hintText: 'Explain why you want to evolve your avatar...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a reason';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRequestingEvolution ? null : _requestEvolution,
                icon: _isRequestingEvolution
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isRequestingEvolution
                    ? 'Requesting...'
                    : 'Request Evolution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build evolution requirements display
  Widget _buildEvolutionRequirements() {
    final reqs = _evolutionRequirements!;
    final canEvolve = reqs['can_evolve'] as bool;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canEvolve
            ? Theme.of(context)
                .colorScheme
                .primaryContainer
                .withValues(alpha: 0.3)
            : Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canEvolve
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canEvolve ? Icons.check_circle : Icons.info_outline,
                color: canEvolve
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                canEvolve ? 'Ready to Evolve!' : 'Evolution Requirements',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: canEvolve
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirementProgress(
            label: 'Deep Conversations',
            current: reqs['deep_conversations'] as int,
            required: reqs['required_deep_conversations'] as int,
          ),
          const SizedBox(height: 8),
          _buildRequirementProgress(
            label: 'Average Novelty',
            current: ((reqs['average_novelty'] as double) * 100).toInt(),
            required: ((reqs['required_novelty'] as double) * 100).toInt(),
            isPercentage: true,
          ),
        ],
      ),
    );
  }

  /// Build requirement progress widget
  Widget _buildRequirementProgress({
    required String label,
    required int current,
    required int required,
    bool isPercentage = false,
  }) {
    final isMet = current >= required;
    final progress = (current / required).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '$current${isPercentage ? '%' : ''} / $required${isPercentage ? '%' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isMet
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              isMet
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
