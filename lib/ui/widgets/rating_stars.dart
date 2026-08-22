import 'package:flutter/material.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final full = (rating / 2).floor();
    final hasHalf = (rating / 2) - full >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Icon(
            i < full
                ? Icons.star_rounded
                : (i == full && hasHalf ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: size,
            color: const Color(0xFFFFC107),
          ),
      ],
    );
  }
}
