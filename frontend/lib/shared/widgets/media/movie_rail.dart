import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/media_item.dart';
import '../loading/shimmer_box.dart';
import 'movie_card.dart';

class MovieRail extends StatefulWidget {
  const MovieRail({
    super.key,
    required this.title,
    required this.items,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.onLoadMore,
  });

  final String title;
  final List<MediaItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  @override
  State<MovieRail> createState() => _MovieRailState();
}

class _MovieRailState extends State<MovieRail> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_maybeLoadMoreFromScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_maybeLoadMoreFromScroll)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMoreFromScroll() {
    if (!_controller.hasClients || widget.onLoadMore == null) return;
    final position = _controller.position;
    if (position.extentAfter < 620) widget.onLoadMore?.call();
  }

  void _maybeLoadMoreFromFocus(int index) {
    if (widget.items.length - index <= 5) widget.onLoadMore?.call();
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.horizontalPadding(context);
    final cardWidth = ResponsiveLayout.posterWidth(context);
    final cardHeight = ResponsiveLayout.posterHeight(context);
    final itemCount = widget.isLoading ? 8 : widget.items.length + (widget.isLoadingMore ? 3 : 0);

    if (!widget.isLoading && widget.items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: FocusTraversalGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: cardHeight + 30,
              child: ListView.separated(
                controller: _controller,
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: 4),
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                cacheExtent: 1200,
                addAutomaticKeepAlives: false,
                addSemanticIndexes: false,
                itemBuilder: (context, index) {
                  if (widget.isLoading || index >= widget.items.length) {
                    return ShimmerBox(width: cardWidth, height: cardHeight);
                  }

                  final item = widget.items[index];
                  return MovieCard(
                    item: item,
                    onFocused: () => _maybeLoadMoreFromFocus(index),
                    onPressed: () {
                      final id = item.id.toString();
                      context.push(item.mediaType == 'tv' ? AppRoutes.tv(id) : AppRoutes.movie(id));
                    },
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemCount: itemCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
