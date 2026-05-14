import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/focus_scroll.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/responsive/responsive_layout.dart';
import '../../../models/media_details.dart';
import '../../../models/embed_source.dart';
import '../../../providers/catalog_providers.dart';
import '../../../services/local_library_repository.dart';
import '../loading/shimmer_box.dart';
import 'movie_rail.dart';

class DetailsPageContent extends StatelessWidget {
  const DetailsPageContent({
    super.key,
    required this.details,
  });

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    return _StaggeredIntro(
      child: CustomScrollView(
        key: PageStorageKey('details-${details.mediaType}-${details.id}'),
        cacheExtent: 1400,
        slivers: [
          SliverToBoxAdapter(child: _DetailsHero(details: details)),
          SliverToBoxAdapter(child: _InfoBand(details: details)),
          if (details.cast.isNotEmpty)
            SliverToBoxAdapter(child: CastRail(cast: details.cast)),
          SliverToBoxAdapter(
            child: RecommendationsRail(
              title: 'Recommendations',
              request: CatalogRequest(
                  type: 'recommendations',
                  mediaType: details.mediaType,
                  id: details.id),
            ),
          ),
          SliverToBoxAdapter(
            child: RecommendationsRail(
              title: 'Similar Content',
              request: CatalogRequest(
                  type: 'similar',
                  mediaType: details.mediaType,
                  id: details.id),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}

class RecommendationsRail extends ConsumerWidget {
  const RecommendationsRail({
    super.key,
    required this.title,
    required this.request,
  });

  final String title;
  final CatalogRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(catalogResultsProvider(request));
    if (!state.isLoading && state.items.isEmpty) return const SizedBox.shrink();

    return MovieRail(
      title: title,
      items: state.items,
      isLoading: state.isLoading && state.items.isEmpty,
      isLoadingMore: state.isLoadingMore,
      onLoadMore: ref.read(catalogResultsProvider(request).notifier).loadMore,
    );
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    final isTv = ResponsiveLayout.isTv(context);
    final height = ResponsiveLayout.detailsHeroHeight(context);
    final imageUrl = details.backdropUrl.isNotEmpty
        ? details.backdropUrl
        : details.posterUrl;
    final cacheWidth = (MediaQuery.sizeOf(context).width *
            MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(720, 1280)
        .toInt();

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isEmpty)
            const ColoredBox(color: AppColors.surface)
          else
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              memCacheWidth: cacheWidth,
              maxWidthDiskCache: 1280,
              maxHeightDiskCache: 720,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) =>
                  const ColoredBox(color: AppColors.surface),
              errorWidget: (_, __, ___) =>
                  const ColoredBox(color: AppColors.surface),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF5090909),
                  Color(0x99090909),
                  Color(0x11090909)
                ],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x44000000),
                  Colors.transparent,
                  AppColors.background
                ],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                ResponsiveLayout.horizontalPadding(context),
                22,
                ResponsiveLayout.horizontalPadding(context),
                46,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: isTv ? 760 : 430),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                details.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              if (details.tagline.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  details.tagline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.textMuted),
                                ),
                              ],
                              const SizedBox(height: 16),
                              _MetaRow(details: details),
                              const SizedBox(height: 18),
                              Text(
                                details.overview,
                                maxLines: isTv ? 4 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(height: 1.35),
                              ),
                              const SizedBox(height: 24),
                              _ActionRow(details: details),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _ActionRow extends ConsumerWidget {
  const _ActionRow({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final libraryController = ref.read(libraryControllerProvider.notifier);
    final favorite = library.isFavorite(details);
    final progress = library.progressFor(details);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (details.mediaType == 'movie')
              FilledButton.icon(
                onPressed: () => _openPlayback(context, ref, details),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            if (progress != null)
              FilledButton.icon(
                onPressed: () => _openPlayback(
                  context,
                  ref,
                  details,
                  season: progress.season,
                  episode: progress.episode,
                ),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Resume'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  foregroundColor: Colors.white,
                  textStyle: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            FilledButton.icon(
              onPressed: () => libraryController.toggleFavorite(details),
              icon: Icon(favorite ? Icons.check_rounded : Icons.add_rounded),
              label: Text(favorite ? 'In My List' : 'My List'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                foregroundColor: Colors.white,
                textStyle: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (details.mediaType == 'tv') ...[
          const SizedBox(height: 18),
          _TvEpisodePicker(details: details),
        ],
      ],
    );
  }
}

class _TvEpisodePicker extends ConsumerStatefulWidget {
  const _TvEpisodePicker({required this.details});

  final MediaDetails details;

  @override
  ConsumerState<_TvEpisodePicker> createState() => _TvEpisodePickerState();
}

class _TvEpisodePickerState extends ConsumerState<_TvEpisodePicker> {
  int _season = 1;
  int _episode = 1;

  @override
  void initState() {
    super.initState();
    final progress =
        ref.read(libraryControllerProvider).progressFor(widget.details);
    _season = progress?.season ?? 1;
    _episode = progress?.episode ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final seasonCount = (widget.details.numberOfSeasons ?? 1).clamp(1, 99);
    final season = ref.watch(tvSeasonProvider(
        TvSeasonRequest(id: widget.details.id, season: _season)));

    return season.when(
      data: (season) {
        final episodes = season.episodes.isEmpty
            ? List.generate(
                1,
                (index) => TvEpisode(
                    seasonNumber: _season,
                    episodeNumber: index + 1,
                    name: 'Episode ${index + 1}'))
            : season.episodes;
        final selectedEpisode =
            episodes.any((episode) => episode.episodeNumber == _episode)
                ? _episode
                : episodes.first.episodeNumber;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<int>(
                  value: _season,
                  dropdownColor: AppColors.surfaceRaised,
                  items: [
                    for (var season = 1; season <= seasonCount; season++)
                      DropdownMenuItem(
                          value: season, child: Text('Season $season')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _season = value;
                      _episode = 1;
                    });
                  },
                ),
                DropdownButton<int>(
                  value: selectedEpisode,
                  dropdownColor: AppColors.surfaceRaised,
                  items: [
                    for (final episode in episodes)
                      DropdownMenuItem(
                        value: episode.episodeNumber,
                        child: Text('Episode ${episode.episodeNumber}'),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _episode = value);
                  },
                ),
                FilledButton.icon(
                  onPressed: () => _openPlayback(context, ref, widget.details,
                      season: _season, episode: selectedEpisode),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play Episode'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    textStyle: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: episodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final episode = episodes[index];
                  final selected = episode.episodeNumber == selectedEpisode;
                  return ChoiceChip(
                    label: Text('${episode.episodeNumber}'),
                    selected: selected,
                    selectedColor: AppColors.netflixRed,
                    backgroundColor: AppColors.surfaceRaised,
                    onSelected: (_) =>
                        setState(() => _episode = episode.episodeNumber),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (_, __) => FilledButton.icon(
        onPressed: () => _openPlayback(context, ref, widget.details,
            season: _season, episode: _episode),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Play Episode 1'),
      ),
      loading: () => const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.netflixRed),
      ),
    );
  }
}

Future<void> _openPlayback(
    BuildContext context, WidgetRef ref, MediaDetails details,
    {int? season, int? episode}) async {
  final id = details.id.toString();
  final route = details.mediaType == 'tv'
      ? AppRoutes.playTv(
          id,
          details.title,
          season ?? 1,
          episode ?? 1,
          posterUrl: details.posterUrl,
          backdropUrl: details.backdropUrl,
        )
      : AppRoutes.playMovie(id, details.title,
          posterUrl: details.posterUrl, backdropUrl: details.backdropUrl);
  await ref.read(libraryControllerProvider.notifier).saveProgress(
        details,
        positionSeconds: 0,
        durationSeconds: (details.runtime ?? 60) * 60,
        season: season,
        episode: episode,
      );
  if (context.mounted) context.push(route);
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    final values = [
      if (details.year.isNotEmpty) details.year,
      if (details.runtimeLabel.isNotEmpty) details.runtimeLabel,
      if (details.mediaType == 'tv' && details.numberOfSeasons != null)
        '${details.numberOfSeasons} seasons',
      if (details.status != null && details.status!.isNotEmpty) details.status!,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.netflixRed,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            details.voteAverage.toStringAsFixed(1),
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        for (final value in values)
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w700,
                ),
          ),
      ],
    );
  }
}

class _InfoBand extends StatelessWidget {
  const _InfoBand({required this.details});

  final MediaDetails details;

  @override
  Widget build(BuildContext context) {
    final genres = details.genres
        .map((genre) => genre.name)
        .where((name) => name.isNotEmpty)
        .join(' / ');

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveLayout.horizontalPadding(context),
        0,
        ResponsiveLayout.horizontalPadding(context),
        30,
      ),
      child: FocusTraversalGroup(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (genres.isNotEmpty)
              _InfoChip(icon: Icons.category_rounded, text: genres),
            if (details.releaseDate != null)
              _InfoChip(icon: Icons.event_rounded, text: details.releaseDate!),
            _InfoChip(
                icon: Icons.star_rounded,
                text: '${details.voteAverage.toStringAsFixed(1)} rating'),
            if (details.voteCount > 0)
              _InfoChip(
                  icon: Icons.people_alt_rounded,
                  text: '${details.voteCount} votes'),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width -
        (ResponsiveLayout.horizontalPadding(context) * 2);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CastRail extends StatelessWidget {
  const CastRail({super.key, required this.cast});

  final List<CastMember> cast;

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.horizontalPadding(context);
    final width = ResponsiveLayout.isTv(context) ? 132.0 : 112.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Text(
              'Cast',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: width + 78,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: padding),
              scrollDirection: Axis.horizontal,
              cacheExtent: 900,
              itemCount: cast.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) =>
                  _CastCard(member: cast[index], width: width),
            ),
          ),
        ],
      ),
    );
  }
}

class _CastCard extends StatefulWidget {
  const _CastCard({required this.member, required this.width});

  final CastMember member;
  final double width;

  @override
  State<_CastCard> createState() => _CastCardState();
}

class _CastCardState extends State<_CastCard> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || _hovered;
    final cacheSize = (widget.width * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(96, 220)
        .toInt();

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.basic,
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onFocusChange: (focused) {
        if (focused) FocusScroll.keepVisible(context);
      },
      child: AnimatedScale(
        scale: active ? 1.05 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: widget.width,
                  height: widget.width,
                  child: widget.member.profileUrl.isEmpty
                      ? const ColoredBox(color: AppColors.skeletonBase)
                      : CachedNetworkImage(
                          imageUrl: widget.member.profileUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: cacheSize,
                          memCacheHeight: cacheSize,
                          maxWidthDiskCache: 220,
                          maxHeightDiskCache: 220,
                          placeholder: (_, __) =>
                              const ColoredBox(color: AppColors.skeletonBase),
                          errorWidget: (_, __, ___) =>
                              const ColoredBox(color: AppColors.skeletonBase),
                        ),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                widget.member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                widget.member.character,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DetailsLoadingView extends StatelessWidget {
  const DetailsLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isTv = ResponsiveLayout.isTv(context);
    final height = ResponsiveLayout.detailsHeroHeight(context);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.surface),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    ResponsiveLayout.horizontalPadding(context),
                    0,
                    ResponsiveLayout.horizontalPadding(context),
                    48,
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(width: isTv ? 560 : 300, height: 58),
                        const SizedBox(height: 16),
                        ShimmerBox(width: isTv ? 400 : 260, height: 22),
                        const SizedBox(height: 18),
                        ShimmerBox(width: isTv ? 700 : 330, height: 18),
                        const SizedBox(height: 8),
                        ShimmerBox(width: isTv ? 620 : 280, height: 18),
                        const SizedBox(height: 24),
                        const Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ShimmerBox(width: 116, height: 44),
                            ShimmerBox(width: 164, height: 44),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DetailsErrorView extends StatelessWidget {
  const DetailsErrorView({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.netflixRed),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaggeredIntro extends StatefulWidget {
  const _StaggeredIntro({required this.child});

  final Widget child;

  @override
  State<_StaggeredIntro> createState() => _StaggeredIntroState();
}

class _StaggeredIntroState extends State<_StaggeredIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide =
        Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(_fade);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
