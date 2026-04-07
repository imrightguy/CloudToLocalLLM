import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudtolocalllm/features/avatar/avatar_widget.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';
import 'package:cloudtolocalllm/widgets/navigation/breadcrumb_bar.dart';

/// Screen for customizing avatar visual appearance
/// Allows users to customize avatar type, color, size, and effects
class AvatarCustomizationScreen extends StatefulWidget {
  const AvatarCustomizationScreen({super.key});

  @override
  State<AvatarCustomizationScreen> createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState extends State<AvatarCustomizationScreen> {
  // Form key
  final _formKey = GlobalKey<FormState>();

  // Service
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Current settings
  String _avatarType = 'emoji'; // 'emoji' or 'rive'
  String _avatarSize = 'medium'; // 'small', 'medium', 'large'
  bool _glowEnabled = true;
  Color? _customColor; // null = use personality-derived colors

  // Preview state
  AgentState _previewState = AgentState.idle;

  /// Size multipliers for avatar
  static const Map<String, double> _avatarSizeMultipliers = {
    'small': 0.8,
    'medium': 1.0,
    'large': 1.3,
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      _prefs = await SharedPreferences.getInstance();

      setState(() {
        _avatarType = _prefs.getString('avatar_type') ?? 'emoji';
        _avatarSize = _prefs.getString('avatar_size') ?? 'medium';
        _glowEnabled = _prefs.getBool('avatar_glow_enabled') ?? true;

        final colorHex = _prefs.getString('avatar_color_override');
        _customColor = colorHex != null
            ? Color(int.parse(colorHex.substring(2), radix: 16))
            : null;

        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      await _prefs.setString('avatar_type', _avatarType);
      await _prefs.setString('avatar_size', _avatarSize);
      await _prefs.setBool('avatar_glow_enabled', _glowEnabled);

      if (_customColor != null) {
        final colorHex =
            '#${_customColor!.toARGB32().toRadixString(16).substring(2)}';
        await _prefs.setString('avatar_color_override', colorHex);
      } else {
        await _prefs.remove('avatar_color_override');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar customization saved successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Reset to personality-derived colors
  void _resetColors() {
    setState(() {
      _customColor = null;
    });
  }

  /// Reset all settings to defaults
  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
            'Are you sure you want to reset all avatar settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _prefs.remove('avatar_type');
      await _prefs.remove('avatar_size');
      await _prefs.remove('avatar_glow_enabled');
      await _prefs.remove('avatar_color_override');

      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar settings reset to defaults'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Get avatar size in pixels
  double _getAvatarSize() {
    final baseSize = 150.0;
    final multiplier = _avatarSizeMultipliers[_avatarSize] ?? 1.0;
    return baseSize * multiplier;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Avatar Customization'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Avatar Customization'),
        leading: BackButton(
          onPressed: () => context.go('/settings/avatar'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to defaults',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      body: Column(
        children: [
          const AutoBreadcrumbBar(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Preview Section
                  _buildPreviewSection(colorScheme),

                  const SizedBox(height: 24),

                  // Avatar Type Selector
                  _buildAvatarTypeSection(colorScheme),

                  const SizedBox(height: 24),

                  // Color Picker Section
                  _buildColorSection(colorScheme),

                  const SizedBox(height: 24),

                  // Size Selector
                  _buildSizeSection(colorScheme),

                  const SizedBox(height: 24),

                  // Glow Effect Toggle
                  _buildGlowSection(colorScheme),

                  const SizedBox(height: 32),

                  // Save Button
                  FilledButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Customization'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(ColorScheme colorScheme) {
    final avatarColor =
        _customColor ?? colorScheme.primary.withValues(alpha: 0.8);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Avatar Preview',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 16),
            // Avatar preview
            Container(
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: avatarColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(32),
              child: AgentAvatar(
                state: _previewState,
                size: _getAvatarSize(),
                personality: PersonalityTraits.defaultTraits,
              ),
            ),
            const SizedBox(height: 16),
            // State switcher for preview
            SegmentedButton<AgentState>(
              segments: const [
                ButtonSegment(
                  value: AgentState.idle,
                  label: Text('Idle'),
                  icon: Icon(Icons.pause_circle_outline),
                ),
                ButtonSegment(
                  value: AgentState.thinking,
                  label: Text('Thinking'),
                  icon: Icon(Icons.psychology),
                ),
                ButtonSegment(
                  value: AgentState.happy,
                  label: Text('Happy'),
                  icon: Icon(Icons.sentiment_satisfied),
                ),
              ],
              selected: {_previewState},
              onSelectionChanged: (state) {
                setState(() => _previewState = state.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarTypeSection(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.style, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Avatar Type',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _avatarType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'emoji',
                  child: Text('Emoji'),
                ),
                DropdownMenuItem(
                  value: 'rive',
                  enabled: false, // Disabled until .riv file exists
                  child: Text('Rive Animation'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _avatarType = value);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Rive animations coming soon! Emoji avatar currently available.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSection(ColorScheme colorScheme) {
    final hasCustomColor = _customColor != null;
    final avatarColor =
        _customColor ?? colorScheme.primary.withValues(alpha: 0.8);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Avatar Color',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Color preview
                GestureDetector(
                  onTap: _pickColor,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colorScheme.outline,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasCustomColor
                            ? 'Custom color selected'
                            : 'Using personality-derived colors',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickColor,
                        icon: const Icon(Icons.edit),
                        label: const Text('Pick Color'),
                      ),
                      if (hasCustomColor) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _resetColors,
                          icon: const Icon(Icons.autorenew),
                          label: const Text('Use personality colors'),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSection(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Avatar Size',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'small',
                  label: Text('Small'),
                  icon: Icon(Icons.circle, size: 16),
                ),
                ButtonSegment(
                  value: 'medium',
                  label: Text('Medium'),
                  icon: Icon(Icons.circle, size: 24),
                ),
                ButtonSegment(
                  value: 'large',
                  label: Text('Large'),
                  icon: Icon(Icons.circle, size: 32),
                ),
              ],
              selected: {_avatarSize},
              onSelectionChanged: (size) {
                setState(() => _avatarSize = size.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowSection(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.light_mode, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Glow Effect',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable pulsing glow effect around avatar',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Switch(
              value: _glowEnabled,
              onChanged: (value) {
                setState(() => _glowEnabled = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Open color picker dialog
  Future<void> _pickColor() async {
    final colorScheme = Theme.of(context).colorScheme;
    final pickerColor = _customColor ?? colorScheme.primary;
    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick Avatar Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (Color color) {
              // Color changed
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(pickerColor);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (pickedColor != null) {
      setState(() => _customColor = pickedColor);
    }
  }
}
