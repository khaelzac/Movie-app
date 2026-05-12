import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/media_item.dart';
import '../loading/shimmer_box.dart';
import 'movie_card.dart';

class MediaGrid extends StatelessWidget {
  const MediaGrid({
    super.key,
    required this.items,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.onNearEnd,
  });

  final List<MediaItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback? onNearEnd;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.horizontalPadding(context);
    final width = ResponsiveLayout.posterWidth(context);
    final height = ResponsiveLayout.posterHeight(context);
    final itemCount = isLoading ? 18 : items.length + (isLoadingMore ? 6 : 0);

    if (!isLoading && items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(padding, 8, padding, 36),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (isLoading || index >= items.length) {
              return Center(child: ShimmerBox(width: width, height: height));
            }

            final item = items[index];
            return Center(
              child: MovieCard(
                item: item,
                onFocused: () {
                  if (items.length - index <= 8) onNearEnd?.call();
                },
                onPressed: () {
                  final id = item.id.toString();
                  context.push(item.mediaType == 'tv' ? AppRoutes.tv(id) : AppRoutes.movie(id));
                },
              ),
            );
          },
          childCount: itemCount,
          addAutomaticKeepAlives: false,
          addSemanticIndexes: false,
        ),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: width + 34,
          mainAxisExtent: height + 38,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
        ),
      ),
    );
  }
}
