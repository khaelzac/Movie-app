import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../services/local_library_repository.dart';
import 'movie_card.dart';

class ContinueWatchingRail extends StatelessWidget {
  const ContinueWatchingRail({
    super.key,
    required this.items,
    this.title = 'Continue Watching',
    this.onClear,
  });

  final List<PlaybackProgress> items;
  final String title;
  final ValueChanged<PlaybackProgress>? onClear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final padding = ResponsiveLayout.horizontalPadding(context);
    final cardHeight = ResponsiveLayout.posterHeight(context);
    final railHeight = cardHeight + 96;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: railHeight,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
                scrollDirection: Axis.horizontal,
                cacheExtent: 900,
                physics: const ClampingScrollPhysics(),
                addAutomaticKeepAlives: false,
                addSemanticIndexes: false,
                itemBuilder: (context, index) {
                  final progress = items[index];
                  return _ProgressCard(
                    progress: progress,
                    onClear:
                        onClear == null ? null : () => onClear?.call(progress),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: items.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    this.onClear,
  });

  final PlaybackProgress progress;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final width = ResponsiveLayout.posterWidth(context);
    final item = progress.item;

    return SizedBox(
      width: width,
      height: ResponsiveLayout.posterHeight(context) + 88,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MovieCard(
            item: item,
            onPressed: () {
              final id = item.id.toString();
              if (item.mediaType == 'tv') {
                context.push(
                  AppRoutes.playTv(
                    id,
                    item.title,
                    progress.season ?? 1,
                    progress.episode ?? 1,
                    posterUrl: item.posterUrl,
                    backdropUrl: item.backdropUrl,
                  ),
                );
              } else {
                context.push(AppRoutes.playMovie(id, item.title,
                    posterUrl: item.posterUrl, backdropUrl: item.backdropUrl));
              }
            },
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress.fraction,
                backgroundColor: AppColors.surfaceRaised,
                valueColor: const AlwaysStoppedAnimation(AppColors.netflixRed),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 28,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    progress.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                if (onClear != null)
                  SizedBox.square(
                    dimension: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Remove',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
