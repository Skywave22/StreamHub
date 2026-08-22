import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final color = Color.lerp(base, base.withValues(alpha: 0.35), _controller.value)!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(widget.radius)),
        );
      },
    );
  }
}

class PosterSkeleton extends StatelessWidget {
  const PosterSkeleton({super.key, this.width = 120});
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(aspectRatio: 2 / 3, child: Skeleton(radius: 14)),
          SizedBox(height: 8),
          Skeleton(width: 90),
        ],
      ),
    );
  }
}
