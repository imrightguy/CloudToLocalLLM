class PersonalityTraits {
  final double formality;
  final double humor;
  final double enthusiasm;
  final double empathy;

  PersonalityTraits({
    required this.formality,
    required this.humor,
    required this.enthusiasm,
    required this.empathy,
  }) {
    _validate();
  }

  void _validate() {
    _assertRange('formality', formality);
    _assertRange('humor', humor);
    _assertRange('enthusiasm', enthusiasm);
    _assertRange('empathy', empathy);
  }

  static void _assertRange(String name, double value) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError('$name must be between 0.0 and 1.0, got $value');
    }
  }

  static double _clamp(double value) => value.clamp(0.0, 1.0);

  Map<String, double> toMap() => {
        'formality': formality,
        'humor': humor,
        'enthusiasm': enthusiasm,
        'empathy': empathy,
      };

  factory PersonalityTraits.fromMap(Map<String, double> map) =>
      PersonalityTraits(
        formality: _clamp(map['formality'] ?? 0.5),
        humor: _clamp(map['humor'] ?? 0.5),
        enthusiasm: _clamp(map['enthusiasm'] ?? 0.5),
        empathy: _clamp(map['empathy'] ?? 0.5),
      );

  String toJson() => toMap().toString();

  static PersonalityTraits get defaultTraits => PersonalityTraits(
        formality: 0.5,
        humor: 0.5,
        enthusiasm: 0.5,
        empathy: 0.5,
      );
}

class EvolutionDecision {
  final bool approved;
  final String? reason;
  final String? newStage;

  EvolutionDecision({
    required this.approved,
    this.reason,
    this.newStage,
  });
}

class ExtendedAvatarProfile {
  final String agentName;
  final PersonalityTraits traits;
  final String evolutionStage;
  final int conversationCount;
  final double depthScore;

  ExtendedAvatarProfile({
    required this.agentName,
    required this.traits,
    required this.evolutionStage,
    required this.conversationCount,
    required this.depthScore,
  });
}
