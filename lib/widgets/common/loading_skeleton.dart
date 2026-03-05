import 'package:flutter/material.dart';

class LoadingSkeleton extends StatelessWidget {
  final int itemCount;
  final double height;

  const LoadingSkeleton({
    this.itemCount = 5,
    this.height = 72,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SkeletonLine(height: height),
        );
      },
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double height;

  const _SkeletonLine({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
