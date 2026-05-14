import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/media_item.dart';
import '../../providers/catalog_providers.dart';
import '../../shared/widgets/loading/shimmer_box.dart';
import '../../shared/widgets/media/hero_banner.dart';
import '../../shared/widgets/media/movie_rail.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(homeRailProvider('trending'));
    final hero = trending.items.isNotEmpty ? trending.items.first : null;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
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
              const SliverToBoxAdapter(
                  child: _HomeRail(title: 'Trending', railKey: 'trending')),
              const SliverToBoxAdapter(
                  child: _HomeRail(
                      title: 'Popular Movies', railKey: 'popularMovies')),
              const SliverToBoxAdapter(
                  child: _HomeRail(
                      title: 'Popular TV Shows', railKey: 'popularTv')),
              const SliverToBoxAdapter(
                  child: _HomeRail(title: 'Top Rated', railKey: 'topRated')),
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
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              for (final slug in homeGenreSlugs)
                SliverToBoxAdapter(
                  child: _HomeRail(
                      title: homeGenreTitle(slug), railKey: 'genre:$slug'),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
          const _HomeTopBar(),
        ],
      ),
    );
  }

  static void _openDetails(BuildContext context, MediaItem item) {
    final id = item.id.toString();
    context
        .push(item.mediaType == 'tv' ? AppRoutes.tv(id) : AppRoutes.movie(id));
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar();

  @override
  Widget build(BuildContext context) {
    final isTv = ResponsiveLayout.isTv(context);
    final padding = ResponsiveLayout.horizontalPadding(context);

    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6090909), Color(0x00090909)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, isTv ? 18 : 10, padding, 28),
            child: Row(
              children: [
                Text(
                  'OCAMPOFLIX',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.netflixRed,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                ),
                if (isTv) ...[
                  const SizedBox(width: 28),
                  _TopBarLink(
                    label: 'Home',
                    onPressed: () => context.go(AppRoutes.home),
                  ),
                  _TopBarLink(
                    label: 'Search',
                    onPressed: () => context.push(AppRoutes.search),
                  ),
                  _TopBarLink(
                    label: 'My List',
                    onPressed: () => context.push(AppRoutes.myList),
                  ),
                ],
                const Spacer(),
                Tooltip(
                  message: 'Search',
                  child: IconButton.filled(
                    onPressed: () => context.push(AppRoutes.search),
                    icon: const Icon(Icons.search_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.48),
                      foregroundColor: Colors.white,
                      fixedSize: Size.square(isTv ? 48 : 42),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarLink extends StatelessWidget {
  const _TopBarLink({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(label),
    );
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
    final height = ResponsiveLayout.homeHeroHeight(context);

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
              isTv ? 70 : 38,
              ResponsiveLayout.horizontalPadding(context),
              34,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: isTv ? 680 : double.infinity),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                          width: isTv ? 520 : 280, height: 58, borderRadius: 6),
                      const SizedBox(height: 16),
                      ShimmerBox(
                          width: isTv ? 620 : 320, height: 18, borderRadius: 4),
                      const SizedBox(height: 8),
                      ShimmerBox(
                          width: isTv ? 500 : 260, height: 18, borderRadius: 4),
                      const SizedBox(height: 22),
                      const Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ShimmerBox(width: 112, height: 44, borderRadius: 6),
                          ShimmerBox(width: 148, height: 44, borderRadius: 6),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
