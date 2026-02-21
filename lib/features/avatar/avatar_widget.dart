import 'package:flutter/material.dart';

/// Represents the current expression/state of the agent.
enum AgentState {
  idle,
  thinking,
  working,
  error,
  happy,
}

/// An expressive avatar for Zoidbot that reacts to the agent's state.
///
/// Currently uses a reactive placeholder.
/// Recommended final implementation: Rive (.riv) for state-driven vector animations.
class AgentAvatar extends StatefulWidget {
  final AgentState state;
  final double size;

  const AgentAvatar({
    super.key,
    required this.state,
    this.size = 150,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Switch visual properties based on state
    Color baseColor;
    String emoji;
    double scale = 1.0;
    bool isPulsing = false;

    switch (widget.state) {
      case AgentState.idle:
        baseColor = theme.primaryColor;
        emoji = '🦞';
        break;
      case AgentState.thinking:
        baseColor = Colors.amber;
        emoji = '🤔';
        isPulsing = true;
        break;
      case AgentState.working:
        baseColor = Colors.blue;
        emoji = '⚡';
        isPulsing = true;
        break;
      case AgentState.error:
        baseColor = Colors.red;
        emoji = '💢';
        break;
      case AgentState.happy:
        baseColor = Colors.green;
        emoji = '✨';
        scale = 1.2;
        break;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = isPulsing ? (0.95 + (_controller.value * 0.1)) : 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: widget.size * pulse * scale,
          height: widget.size * pulse * scale,
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
