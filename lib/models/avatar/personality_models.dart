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
  });

  Map<String, double> toMap() => {
        'formality': formality,
        'humor': humor,
        'enthusiasm': enthusiasm,
        'empathy': empathy,
      };

  factory PersonalityTraits.fromMap(Map<String, double> map) => PersonalityTraits(
        formality: map['formality'] ?? 0.5,
        humor: map['humor'] ?? 0.5,
        enthusiasm: map['enthusiasm'] ?? 0.5,
        empathy: map['empathy'] ?? 0.5,
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
