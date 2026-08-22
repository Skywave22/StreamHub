import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';

/// A full-bleed poster tile with an overlaid title, used in grids.
class PosterTile extends StatelessWidget {
  const PosterTile({super.key, required this.item, required this.onTap});

  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.posterUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: scheme.surfaceContainerHighest),
                errorWidget: (_, __, ___) => Container(
                  color: scheme.surfaceContainerHighest,
                  child: Center(child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant)),
                ),
              )
            else
              Container(color: scheme.surfaceContainerHighest, child: Center(child: Icon(Icons.movie_outlined, color: scheme.onSurfaceVariant))),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.85)],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            if (item.rating != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFC107)),
                    const SizedBox(width: 2),
                    Text(item.rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  if (item.releaseYear != null)
                    Text('${item.releaseYear}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
