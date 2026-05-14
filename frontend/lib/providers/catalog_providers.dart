import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../models/media_details.dart';
import '../models/embed_source.dart';
import '../services/catalog_repository.dart';
import '../services/embed_repository.dart';

typedef MediaPageLoader = Future<List<MediaItem>> Function(
  CatalogRepository repository,
  int page,
);

final trendingProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).trending();
});

final popularMoviesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).popularMovies();
});

final popularTvProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).popularTv();
});

final topRatedProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(catalogRepositoryProvider).topRated();
});

final genreRailProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, slug) {
  return ref.watch(catalogRepositoryProvider).genre(slug);
});

final searchProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, query) {
  if (query.trim().length < 2) return const [];
  return ref.watch(catalogRepositoryProvider).search(query.trim());
});

final movieDetailsProvider =
    FutureProvider.family<MediaDetails, int>((ref, id) {
  return ref.watch(catalogRepositoryProvider).movieDetails(id);
});

final tvDetailsProvider = FutureProvider.family<MediaDetails, int>((ref, id) {
  return ref.watch(catalogRepositoryProvider).tvDetails(id);
});

final tvSeasonProvider =
    FutureProvider.family<TvSeason, TvSeasonRequest>((ref, request) {
  return ref
      .watch(embedRepositoryProvider)
      .tvSeason(request.id, request.season);
});

final embedProvidersProvider = FutureProvider<List<EmbedProviderInfo>>((ref) {
  return ref.watch(embedRepositoryProvider).providers();
});

final embedSourceProvider = FutureProvider.autoDispose
    .family<EmbedSource, EmbedRequest>((ref, request) {
  ref.cacheFor(const Duration(seconds: 20));

  final repository = ref.watch(embedRepositoryProvider);
  if (request.mediaType == 'tv') {
    return repository.tv(request.id, request.season ?? 1, request.episode ?? 1,
        provider: request.provider);
  }
  return repository.movie(request.id, provider: request.provider);
});

final genresProvider =
    FutureProvider.family<List<Genre>, String>((ref, mediaType) {
  return ref.watch(catalogRepositoryProvider).genres(mediaType: mediaType);
});

final searchResultsProvider =
    StateNotifierProvider.family<PagedMediaController, HomeRailState, String>(
        (ref, query) {
  return PagedMediaController(
    repository: ref.watch(catalogRepositoryProvider),
    loader: (repository, page) {
      final trimmed = query.trim();
      if (trimmed.length < 2) return Future.value(const <MediaItem>[]);
      return repository.search(trimmed, page: page);
    },
  )..loadInitial();
});

final catalogResultsProvider = StateNotifierProvider.family<
    PagedMediaController, HomeRailState, CatalogRequest>((ref, request) {
  return PagedMediaController(
    repository: ref.watch(catalogRepositoryProvider),
    loader: (repository, page) => switch (request.type) {
      'trending' =>
        repository.trending(mediaType: request.mediaType, page: page),
      'popular' => repository.popularMovies(page: page),
      'popular-tv' => repository.popularTv(page: page),
      'top-rated' =>
        repository.topRated(mediaType: request.mediaType, page: page),
      'recommendations' => repository.recommendations(request.id ?? 0,
          mediaType: request.mediaType, page: page),
      'similar' => repository.similar(request.id ?? 0,
          mediaType: request.mediaType, page: page),
      _ => repository.genre(request.genreId?.toString() ?? request.type,
          mediaType: request.mediaType, page: page),
    },
  )..loadInitial();
});

final homeRailProvider =
    StateNotifierProvider.family<HomeRailController, HomeRailState, String>(
        (ref, key) {
  return HomeRailController(
    repository: ref.watch(catalogRepositoryProvider),
    loader: _homeRailLoaders[key] ?? _homeRailLoaders['trending']!,
  )..loadInitial();
});

const homeGenreSlugs = ['action', 'comedy', 'horror', 'anime'];

String homeGenreTitle(String slug) {
  return switch (slug) {
    'action' => 'Action',
    'comedy' => 'Comedy',
    'horror' => 'Horror',
    'anime' => 'Anime',
    _ => slug,
  };
}

final Map<String, MediaPageLoader> _homeRailLoaders = {
  'trending': (repository, page) => repository.trending(page: page),
  'popularMovies': (repository, page) => repository.popularMovies(page: page),
  'popularTv': (repository, page) => repository.popularTv(page: page),
  'topRated': (repository, page) => repository.topRated(page: page),
  for (final slug in homeGenreSlugs)
    'genre:$slug': (repository, page) => repository.genre(slug, page: page),
};

class CatalogRequest {
  const CatalogRequest({
    required this.type,
    this.mediaType = 'movie',
    this.genreId,
    this.id,
  });

  final String type;
  final String mediaType;
  final int? genreId;
  final int? id;

  @override
  bool operator ==(Object other) {
    return other is CatalogRequest &&
        other.type == type &&
        other.mediaType == mediaType &&
        other.genreId == genreId &&
        other.id == id;
  }

  @override
  int get hashCode => Object.hash(type, mediaType, genreId, id);
}

class TvSeasonRequest {
  const TvSeasonRequest({required this.id, required this.season});

  final int id;
  final int season;

  @override
  bool operator ==(Object other) =>
      other is TvSeasonRequest && other.id == id && other.season == season;

  @override
  int get hashCode => Object.hash(id, season);
}

class EmbedRequest {
  const EmbedRequest({
    required this.mediaType,
    required this.id,
    this.season,
    this.episode,
    this.provider,
  });

  final String mediaType;
  final int id;
  final int? season;
  final int? episode;
  final String? provider;

  EmbedRequest copyWith({
    String? mediaType,
    int? id,
    int? season,
    int? episode,
    String? provider,
    bool clearProvider = false,
  }) {
    return EmbedRequest(
      mediaType: mediaType ?? this.mediaType,
      id: id ?? this.id,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      provider: clearProvider ? null : provider ?? this.provider,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EmbedRequest &&
        other.mediaType == mediaType &&
        other.id == id &&
        other.season == season &&
        other.episode == episode &&
        other.provider == provider;
  }

  @override
  int get hashCode => Object.hash(mediaType, id, season, episode, provider);
}

class HomeRailState {
  const HomeRailState({
    this.items = const [],
    this.page = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final List<MediaItem> items;
  final int page;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  HomeRailState copyWith({
    List<MediaItem>? items,
    int? page,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return HomeRailState(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class HomeRailController extends StateNotifier<HomeRailState> {
  HomeRailController({
    required CatalogRepository repository,
    required MediaPageLoader loader,
  })  : _repository = repository,
        _loader = loader,
        super(const HomeRailState());

  final CatalogRepository _repository;
  final MediaPageLoader _loader;

  Future<void> loadInitial() async {
    if (state.isLoading || state.items.isNotEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _loader(_repository, 1);
      state = state.copyWith(
        items: items,
        page: 1,
        isLoading: false,
        hasMore: items.isNotEmpty,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final nextPage = state.page + 1;
      final items = await _loader(_repository, nextPage);
      state = state.copyWith(
        items: [...state.items, ...items],
        page: nextPage,
        isLoadingMore: false,
        hasMore: items.isNotEmpty,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error);
    }
  }
}

class PagedMediaController extends HomeRailController {
  PagedMediaController({
    required super.repository,
    required super.loader,
  });
}

extension CacheForExtension on Ref<Object?> {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
