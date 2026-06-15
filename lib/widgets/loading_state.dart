import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Shimmer skeleton loader for dashboard pages.
/// Mimics the shape of content before real data arrives.
class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment(_animation.value, 0),
          end: Alignment(_animation.value + 2, 0),
          colors: const [
            AppColors.surfaceVariant,
            AppColors.border,
            AppColors.surfaceVariant,
          ],
        );
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period selector placeholder
              _ShimmerBox(
                width: 180,
                height: 36,
                gradient: gradient,
                radius: AppSpacing.radiusControl,
              ),
              const SizedBox(height: AppSpacing.xl),
              // 4 KPI cards row
              Row(
                children: List.generate(
                  4,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: _ShimmerBox(
                        width: double.infinity,
                        height: 120,
                        gradient: gradient,
                        radius: AppSpacing.radiusCard,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // 2 large chart placeholders
              _ShimmerBox(
                width: double.infinity,
                height: 200,
                gradient: gradient,
                radius: AppSpacing.radiusCard,
              ),
              const SizedBox(height: AppSpacing.lg),
              _ShimmerBox(
                width: double.infinity,
                height: 240,
                gradient: gradient,
                radius: AppSpacing.radiusCard,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer skeleton for list screens (buildings, leases, leads, etc.).
class ListSkeleton extends StatefulWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 6,
    this.showSearchBar = true,
  });

  final int itemCount;
  final bool showSearchBar;

  @override
  State<ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment(_animation.value, 0),
          end: Alignment(_animation.value + 2, 0),
          colors: const [
            AppColors.surfaceVariant,
            AppColors.border,
            AppColors.surfaceVariant,
          ],
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showSearchBar) ...[
                _ShimmerBox(
                  width: double.infinity,
                  height: 48,
                  gradient: gradient,
                  radius: AppSpacing.radiusCard,
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              // Skeleton rows
              ...List.generate(widget.itemCount, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < widget.itemCount - 1 ? AppSpacing.md : 0,
                  ),
                  child: _ShimmerBox(
                    width: double.infinity,
                    height: 100,
                    gradient: gradient,
                    radius: AppSpacing.radiusCard,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// A simple solid skeleton row for inline loading inside existing layouts.
class SkeletonRow extends StatefulWidget {
  const SkeletonRow({
    super.key,
    this.height = 60,
    this.showCircle = true,
    this.lineCount = 2,
  });

  final double height;
  final bool showCircle;
  final int lineCount;

  @override
  State<SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final gradient = LinearGradient(
          begin: Alignment(_animation.value, 0),
          end: Alignment(_animation.value + 2, 0),
          colors: const [
            AppColors.surfaceVariant,
            AppColors.border,
            AppColors.surfaceVariant,
          ],
        );
        return SizedBox(
          height: widget.height,
          child: Row(
            children: [
              if (widget.showCircle)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: _ShimmerBox(
                    width: widget.height,
                    height: widget.height,
                    gradient: gradient,
                    radius: widget.height / 2,
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    widget.lineCount,
                    (i) => Padding(
                      padding: EdgeInsets.only(
                        bottom: i < widget.lineCount - 1 ? AppSpacing.sm : 0,
                      ),
                      child: _ShimmerBox(
                        width: i == widget.lineCount - 1 ? 120 : double.infinity,
                        height: 14,
                        gradient: gradient,
                        radius: 4,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Internal building block
// ---------------------------------------------------------------------------

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.gradient,
    required this.radius,
  });

  final double? width;
  final double height;
  final LinearGradient gradient;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
      ),
    );
  }
}
