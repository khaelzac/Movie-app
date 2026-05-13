import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/media_details.dart';
import '../../providers/catalog_providers.dart';
import '../../shared/widgets/media/media_grid.dart';

class CatalogPage extends ConsumerStatefulWidget {
  const CatalogPage({super.key, required this.type});

  final String type;

  @override
  ConsumerState<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends ConsumerState<CatalogPage> {
  final _scrollController = ScrollController();
  String _mediaType = 'movie';
  int? _selectedGenreId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 900) {
      final request = _activeRequest();
      if (request != null) {
        ref.read(catalogResultsProvider(request).notifier).loadMore();
      }
    }
  }

  CatalogRequest? _activeRequest([Genre? fallbackGenre]) {
    if (widget.type == 'genres') {
      final genreId = _selectedGenreId ?? fallbackGenre?.id;
      if (genreId == null) return null;
      return CatalogRequest(
          type: 'genre', mediaType: _mediaType, genreId: genreId);
    }
    if (widget.type == 'popular' && _mediaType == 'tv') {
      return const CatalogRequest(type: 'popular-tv', mediaType: 'tv');
    }
    return CatalogRequest(type: widget.type, mediaType: _mediaType);
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.horizontalPadding(context);
    final genres = ref.watch(genresProvider(_mediaType));

    return Scaffold(
      body: SafeArea(
        child: genres.when(
          data: (genreItems) {
            final fallbackGenre = genreItems.isEmpty ? null : genreItems.first;
            final request = _activeRequest(fallbackGenre);
            final state = request == null
                ? const HomeRailState()
                : ref.watch(catalogResultsProvider(request));
            final title = widget.type == 'genres'
                ? (_genreName(
                        genreItems, _selectedGenreId ?? fallbackGenre?.id) ??
                    'Genres')
                : _catalogTitle(request?.type ?? widget.type);

            return CustomScrollView(
              controller: _scrollController,
              cacheExtent: 1400,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(padding, 22, padding, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 16),
                        _MediaTypeToggle(
                          selected: _mediaType,
                          onChanged: (value) {
                            setState(() {
                              _mediaType = value;
                              _selectedGenreId = null;
                            });
                          },
                        ),
                        if (widget.type == 'genres') ...[
                          const SizedBox(height: 16),
                          _GenreSelector(
                            genres: genreItems,
                            selectedId: _selectedGenreId ?? fallbackGenre?.id,
                            onSelected: (genre) =>
                                setState(() => _selectedGenreId = genre.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (request == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: const Text('No genres available.'),
                    ),
                  )
                else if (state.error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Text(state.error.toString()),
                    ),
                  )
                else
                  MediaGrid(
                    items: state.items,
                    isLoading: state.isLoading && state.items.isEmpty,
                    isLoadingMore: state.isLoadingMore,
                    onNearEnd: () => ref
                        .read(catalogResultsProvider(request).notifier)
                        .loadMore(),
                  ),
              ],
            );
          },
          error: (error, _) => Center(child: Text(error.toString())),
          loading: () => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(padding, 22, padding, 12),
                  child: Text(
                    _catalogTitle(widget.type),
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const MediaGrid(items: [], isLoading: true),
            ],
          ),
        ),
      ),
    );
  }

  String? _genreName(List<Genre> genres, int? id) {
    for (final genre in genres) {
      if (genre.id == id) return genre.name;
    }
    return null;
  }

  String _catalogTitle(String type) {
    return switch (type) {
      'trending' => 'Trending',
      'popular' => 'Popular Movies',
      'popular-tv' => 'Popular TV Shows',
      'top-rated' => 'Top Rated',
      'genres' => 'Genres',
      _ => type.replaceAll('-', ' '),
    };
  }
}

class _MediaTypeToggle extends StatelessWidget {
  const _MediaTypeToggle({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
            value: 'movie',
            label: Text('Movies'),
            icon: Icon(Icons.movie_rounded)),
        ButtonSegment(
            value: 'tv',
            label: Text('TV Shows'),
            icon: Icon(Icons.live_tv_rounded)),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.netflixRed
              : AppColors.surfaceRaised,
        ),
        shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
      ),
    );
  }
}

class _GenreSelector extends StatelessWidget {
  const _GenreSelector({
    required this.genres,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Genre> genres;
  final int? selectedId;
  final ValueChanged<Genre> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final genre in genres)
          ChoiceChip(
            label: Text(genre.name),
            selected: genre.id == selectedId,
            onSelected: (_) => onSelected(genre),
            selectedColor: AppColors.netflixRed,
            backgroundColor: AppColors.surfaceRaised,
            labelStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
      ],
    );
  }
}
