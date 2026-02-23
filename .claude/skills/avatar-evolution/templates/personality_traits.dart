/// Avatar Personality Traits Update Template
///
/// Demonstrates how to update avatar personality traits with validation
///
/// Usage:
/// ```dart
/// await updateAvatarPersonality();
/// ```
///
/// See: lib/services/avatar/personality_engine.dart

import 'package:cloudtolocalllm/services/avatar/personality_engine.dart';

/// Update avatar personality traits with validation
Future<void> updateAvatarPersonality() async {
  final engine = PersonalityEngine();

  // Get current personality
  final current = await engine.getPersonality();
  print('Current traits: ${current.traits}');

  // Define new personality traits
  final newTraits = PersonalityTraits(
    formality: 0.7,    // How formal (0.0 = casual, 1.0 = formal)
    humor: 0.6,        // How playful (0.0 = serious, 1.0 = playful)
    enthusiasm: 0.8,   // Energy level (0.0 = calm, 1.0 = enthusiastic)
    empathy: 0.9,      // Emotional warmth (0.0 = direct, 1.0 = empathetic)
  );

  // Validate trait ranges
  if (!_isValidTraitRange(newTraits)) {
    throw ArgumentError(
      'Personality traits must be between 0.0 and 1.0. '
      'Received: formality=${newTraits.formality}, '
      'humor=${newTraits.humor}, '
      'enthusiasm=${newTraits.enthusiasm}, '
      'empathy=${newTraits.empathy}'
    );
  }

  // Update personality
  await engine.updatePersonality(newTraits);
  print('✓ Personality updated');

  // Verify update
  final updated = await engine.getPersonality();
  print('New traits: ${updated.traits}');
}

/// Validate that all personality traits are within valid range (0.0-1.0)
bool _isValidTraitRange(PersonalityTraits traits) {
  return traits.formality >= 0.0 && traits.formality <= 1.0 &&
         traits.humor >= 0.0 && traits.humor <= 1.0 &&
         traits.enthusiasm >= 0.0 && traits.enthusiasm <= 1.0 &&
         traits.empathy >= 0.0 && traits.empathy <= 1.0;
}

/// Personality trait presets for common avatar personalities
class PersonalityPresets {
  /// Professional assistant: high formality, low humor
  static const PersonalityTraits professional = PersonalityTraits(
    formality: 0.9,
    humor: 0.2,
    enthusiasm: 0.5,
    empathy: 0.7,
  );

  /// Friendly companion: balanced traits
  static const PersonalityTraits friendly = PersonalityTraits(
    formality: 0.4,
    humor: 0.7,
    enthusiasm: 0.8,
    empathy: 0.9,
  );

  /// Serious expert: high formality, high empathy
  static const PersonalityTraits expert = PersonalityTraits(
    formality: 0.8,
    humor: 0.3,
    enthusiasm: 0.4,
    empathy: 0.6,
  );

  /// Playful tutor: low formality, high humor and enthusiasm
  static const PersonalityTraits playful = PersonalityTraits(
    formality: 0.3,
    humor: 0.9,
    enthusiasm: 0.9,
    empathy: 0.7,
  );

  /// Balanced default: all traits at 0.5
  static const PersonalityTraits balanced = PersonalityTraits(
    formality: 0.5,
    humor: 0.5,
    enthusiasm: 0.5,
    empathy: 0.5,
  );
}

/// Example usage with presets
Future<void> applyPersonalityPreset() async {
  final engine = PersonalityEngine();

  // Apply friendly preset
  await engine.updatePersonality(PersonalityPresets.friendly);
  print('✓ Applied friendly personality preset');

  // Or create custom personality
  final customTraits = PersonalityTraits(
    formality: 0.6,
    humor: 0.5,
    enthusiasm: 0.7,
    empathy: 0.8,
  );
  await engine.updatePersonality(customTraits);
  print('✓ Applied custom personality');
}
