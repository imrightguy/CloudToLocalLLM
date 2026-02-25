import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/theme_extensions.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsTheme>()!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: [
            // Base background
            Container(color: colors.backgroundMain),

            // Floating Blobs
            _PositionedBlob(
              controller: _controller,
              color: colors.primary.withValues(alpha: 0.1),
              size: 400,
              initialOffset: const Offset(-100, -100),
              moveOffset: const Offset(100, 50),
            ),
            _PositionedBlob(
              controller: _controller,
              color: colors.secondary.withValues(alpha: 0.1),
              size: 500,
              initialOffset: const Offset(200, 300),
              moveOffset: const Offset(-50, -100),
            ),
            _PositionedBlob(
              controller: _controller,
              color: colors.accent.withValues(alpha: 0.05),
              size: 300,
              initialOffset: const Offset(-50, 500),
              moveOffset: const Offset(80, -30),
            ),
          ],
        );
      },
    );
  }
}

class _PositionedBlob extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;
  final Offset initialOffset;
  final Offset moveOffset;

  const _PositionedBlob({
    required this.controller,
    required this.color,
    required this.size,
    required this.initialOffset,
    required this.moveOffset,
  });

  @override
  Widget build(BuildContext context) {
    // Standardize rotation/movement
    final sineValue = math.sin(controller.value * 2 * math.pi);
    final cosValue = math.cos(controller.value * 2 * math.pi);

    final x = initialOffset.dx + moveOffset.dx * sineValue;
    final y = initialOffset.dy + moveOffset.dy * cosValue;

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
