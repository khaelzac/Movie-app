import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/media_item.dart';
import '../../providers/catalog_providers.dart';
import '../../services/local_library_repository.dart';
import '../../shared/widgets/loading/shimmer_box.dart';
import '../../shared/widgets/media/continue_watching_rail.dart';
import '../../shared/widgets/media/hero_banner.dart';
import '../../shared/widgets/media/movie_rail.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(homeRailProvider('trending'));
    final progress = ref.watch(libraryControllerProvider.select((state) => state.progress));
    final hero = trending.items.isNotEmpty ? trending.items.first : null;

    return Scaffold(
      body: CustomScrollView(
        key: const PageStorageKey('home-scroll'),
        cacheExtent: 1400,
        slivers: [
          SliverToBoxAdapter(
            child: hero == null
                ? const _HeroBannerSkeleton()
                : HeroBanner(
                    item: hero,
                    onPlay: () => _openDetails(context, hero),
                    onMoreInfo: () => _openDetails(context, hero),
                  ),
          ),
          SliverToBoxAdapter(
            child: ContinueWatchingRail(
              items: progress,
              onClear: ref.read(libraryControllerProvider.notifier).clearProgress,
            ),
          ),
          const SliverToBoxAdapter(child: _HomeRail(title: 'Trending', railKey: 'trending')),
          const SliverToBoxAdapter(child: _HomeRail(title: 'Popular Movies', railKey: 'popularMovies')),
          const SliverToBoxAdapter(child: _HomeRail(title: 'Popular TV Shows', railKey: 'popularTv')),
          const SliverToBoxAdapter(child: _HomeRail(title: 'Top Rated', railKey: 'topRated')),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.horizontalPadding(context),
                6,
                ResponsiveLayout.horizontalPadding(context),
                18,
              ),
              child: Text(
                'Genres',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          for (final slug in homeGenreSlugs)
            SliverToBoxAdapter(
              child: _HomeRail(title: homeGenreTitle(slug), railKey: 'genre:$slug'),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  static void _openDetails(BuildContext context, MediaItem item) {
    final id = item.id.toString();
    context.push(item.mediaType == 'tv' ? AppRoutes.tv(id) : AppRoutes.movie(id));
  }
}

class _HomeRail extends ConsumerWidget {
  const _HomeRail({required this.title, required this.railKey});

  final String title;
  final String railKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeRailProvider(railKey));
    final controller = ref.read(homeRailProvider(railKey).notifier);

    return MovieRail(
      title: title,
      items: state.items,
      isLoading: state.isLoading && state.items.isEmpty,
      isLoadingMore: state.isLoadingMore,
      onLoadMore: controller.loadMore,
    );
  }
}

class _HeroBannerSkeleton extends StatelessWidget {
  const _HeroBannerSkeleton();

  @override
  Widget build(BuildContext context) {
    final isTv = ResponsiveLayout.isTv(context);
    final height = MediaQuery.sizeOf(context).height * (isTv ? 0.72 : 0.58);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.surface),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.background],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              ResponsiveLayout.horizontalPadding(context),
              isTv ? 70 : 48,
              ResponsiveLayout.horizontalPadding(context),
              42,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: isTv ? 520 : 280, height: 58, borderRadius: 6),
                  const SizedBox(height: 16),
                  ShimmerBox(width: isTv ? 620 : 320, height: 18, borderRadius: 4),
                  const SizedBox(height: 8),
                  ShimmerBox(width: isTv ? 500 : 260, height: 18, borderRadius: 4),
                  const SizedBox(height: 22),
                  Row(
                    children: const [
                      ShimmerBox(width: 112, height: 44, borderRadius: 6),
                      SizedBox(width: 12),
                      ShimmerBox(width: 148, height: 44, borderRadius: 6),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
