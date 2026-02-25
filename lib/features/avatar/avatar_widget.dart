import 'package:flutter/material.dart';
import 'package:cloudtolocalllm/models/avatar/personality_models.dart';

/// Represents the current expression/state of the agent.
enum AgentState {
  idle,
  thinking,
  working,
  error,
  happy,
}

/// An expressive avatar for CloudToLocalLLM that reacts to the agent's state.
///
/// Currently uses a reactive placeholder.
/// Recommended final implementation: Rive (.riv) for state-driven vector animations.
class AgentAvatar extends StatefulWidget {
  final AgentState state;
  final double size;
  final PersonalityTraits? personality;

  const AgentAvatar({
    super.key,
    required this.state,
    this.size = 150,
    this.personality,
  });

  @override
  State<AgentAvatar> createState() => _AgentAvatarState();
}

class _AgentAvatarState extends State<AgentAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(AgentAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // You could trigger specific animations on state change here
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getPersonalityColor(PersonalityTraits? traits) {
    if (traits == null) {
      final theme = Theme.of(context);
      return theme.primaryColor;
    }

    // Hue from empathy (blue 220° → warm 180°)
    final hue = 220 - (traits.empathy * 40);

    // Saturation from enthusiasm (muted 0.5 → vibrant 1.0)
    final saturation = 0.5 + (traits.enthusiasm * 0.5);

    // Lightness from humor (darker 0.4 → brighter 0.6)
    final lightness = 0.4 + (traits.humor * 0.2);

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
  }

  Duration _getPulseDuration(PersonalityTraits? traits) {
    if (traits == null) {
      return const Duration(seconds: 2);
    }

    // Enthusiasm controls speed (1.0s → 0.2s)
    final speedMillis = (1000 - (traits.enthusiasm * 800)).round();
    return Duration(milliseconds: speedMillis);
  }

  double _getBounceScale(PersonalityTraits? traits) {
    if (traits == null) {
      return 1.0;
    }

    // Humor controls bounce (1.0 → 1.2)
    return 1.0 + (traits.humor * 0.2);
  }

  String _getEmojiForState(AgentState state, PersonalityTraits? traits) {
    if (traits == null) {
      return '🦞'; // Default
    }

    // Trait-based emoji selection
    if (traits.humor > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '😜';
        case AgentState.thinking:
          return '🤪';
        case AgentState.working:
          return '⚡';
        case AgentState.error:
          return '💥';
        case AgentState.happy:
          return '🎉';
      }
    }

    if (traits.empathy > 0.8) {
      switch (state) {
        case AgentState.idle:
          return '🤗';
        case AgentState.thinking:
          return '💭';
        case AgentState.working:
          return '💪';
        case AgentState.error:
          return '😢';
        case AgentState.happy:
          return '🥰';
      }
    }

    if (traits.formality > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '🎩';
        case AgentState.thinking:
          return '🧐';
        case AgentState.working:
          return '📊';
        case AgentState.error:
          return '⚠️';
        case AgentState.happy:
          return '✅';
      }
    }

    if (traits.enthusiasm > 0.7) {
      switch (state) {
        case AgentState.idle:
          return '🌟';
        case AgentState.thinking:
          return '💡';
        case AgentState.working:
          return '🚀';
        case AgentState.error:
          return '😵';
        case AgentState.happy:
          return '🎊';
      }
    }

    // Default emoji set
    switch (state) {
      case AgentState.idle:
        return '🦞';
      case AgentState.thinking:
        return '🤔';
      case AgentState.working:
        return '⚡';
      case AgentState.error:
        return '💢';
      case AgentState.happy:
        return '✨';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use personality for dynamic properties
    final baseColor = _getPersonalityColor(widget.personality);
    final pulseDuration = _getPulseDuration(widget.personality);
    final bounceScale = _getBounceScale(widget.personality);

    // Update controller duration based on personality
    if (_controller.duration != pulseDuration) {
      _controller.duration = pulseDuration;
    }

    // Switch emoji based on state (use new method)
    String emoji;
    double scale = 1.0;
    bool isPulsing = false;

    switch (widget.state) {
      case AgentState.idle:
        emoji = _getEmojiForState(widget.state, widget.personality);
        isPulsing = false;
        break;
      case AgentState.thinking:
        emoji = _getEmojiForState(widget.state, widget.personality);
        isPulsing = true;
        break;
      case AgentState.working:
        emoji = _getEmojiForState(widget.state, widget.personality);
        isPulsing = true;
        break;
      case AgentState.error:
        emoji = _getEmojiForState(widget.state, widget.personality);
        break;
      case AgentState.happy:
        emoji = _getEmojiForState(widget.state, widget.personality);
        scale = _getBounceScale(widget.personality);
        break;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = isPulsing ? (0.95 + (_controller.value * 0.1)) : 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: widget.size * pulse * scale * bounceScale,
          height: widget.size * pulse * scale * bounceScale,
          decoration: BoxDecoration(
            color: baseColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: baseColor.withValues(alpha: 0.5),
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: baseColor.withValues(alpha: 0.3),
                blurRadius: 20 * pulse,
                spreadRadius: 5 * pulse,
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Text(
                emoji,
                key: ValueKey(emoji),
                style: TextStyle(fontSize: widget.size * 0.5),
              ),
            ),
          ),
        );
      },
    );
  }
}
