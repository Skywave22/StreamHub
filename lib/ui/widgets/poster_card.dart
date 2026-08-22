import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';

class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.item, required this.onTap, this.width = 120});

  final MediaItem item;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 2 / 3,
                child: _poster(scheme),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (item.releaseYear != null)
              Text(
                '${item.releaseYear}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _poster(ColorScheme scheme) {
    if (item.posterUrl == null || item.posterUrl!.isEmpty) {
      return Container(
        color: scheme.surfaceContainerHighest,
        child: Center(child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: item.posterUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: scheme.surfaceContainerHighest),
          errorWidget: (_, __, ___) => Container(
            color: scheme.surfaceContainerHighest,
            child: Center(child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
          ),
        ),
        if (item.rating != null)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFC107)),
                  const SizedBox(width: 2),
                  Text(
                    item.rating!.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
