import 'package:flutter/material.dart';

import '../../core/models/media_item.dart';
import 'poster_card.dart';
import 'skeletons.dart';

class MediaRail extends StatelessWidget {
  const MediaRail({
    super.key,
    required this.title,
    required this.items,
    this.loading = false,
    this.onTap,
    this.onViewAll,
    this.trailing,
  });

  final String title;
  final List<MediaItem> items;
  final bool loading;
  final ValueChanged<MediaItem>? onTap;
  final VoidCallback? onViewAll;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (!loading && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (trailing != null) trailing!,
              if (onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
        ),
        SizedBox(
          height: 208,
          child: loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, __) => const PosterSkeleton(width: 120),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => PosterCard(
                    item: items[i],
                    onTap: onTap != null ? () => onTap!(items[i]) : () {},
                  ),
                ),
        ),
      ],
    );
  }
}
