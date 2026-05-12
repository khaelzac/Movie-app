import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../models/media_details.dart';
import '../models/media_item.dart';
import 'api_service.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiServiceProvider));
});

class CatalogRepository {
  const CatalogRepository(this._client);

  final ApiService _client;

  Future<List<MediaItem>> _list(String path, {Map<String, dynamic>? query}) async {
    final data = await _client.get(path, queryParameters: query);
    final results = (data['results'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MediaItem.fromJson)
        .where((item) => item.mediaType == 'movie' || item.mediaType == 'tv')
        .where((item) =>
            item.posterUrl.isNotEmpty ||
            item.backdropUrl.isNotEmpty ||
            item.posterPath != null ||
            item.backdropPath != null)
        .toList(growable: false);
    return results;
  }

  Future<List<MediaItem>> trending({String mediaType = 'all', int page = 1}) =>
      _list(ApiEndpoints.trending, query: {'mediaType': mediaType, 'page': page});
  Future<List<MediaItem>> popularMovies({int page = 1}) => _list(ApiEndpoints.popularMovies, query: {'page': page});
  Future<List<MediaItem>> popularTv({int page = 1}) => _list(ApiEndpoints.popularTv, query: {'page': page});
  Future<List<MediaItem>> topRated({String mediaType = 'movie', int page = 1}) =>
      _list(ApiEndpoints.topRated, query: {'mediaType': mediaType, 'page': page});
  Future<List<MediaItem>> genre(String slug, {String mediaType = 'movie', int page = 1}) =>
      _list(ApiEndpoints.genre(slug), query: {'mediaType': mediaType, 'page': page});
  Future<List<MediaItem>> search(String query, {int page = 1}) =>
      _list(ApiEndpoints.search, query: {'query': query, 'page': page});
  Future<MediaDetails> movieDetails(int id) async => MediaDetails.fromJson(await _client.get(ApiEndpoints.movieDetails(id)));
  Future<MediaDetails> tvDetails(int id) async => MediaDetails.fromJson(await _client.get(ApiEndpoints.tvDetails(id)));
  Future<List<Genre>> genres({String mediaType = 'movie'}) async {
    final data = await _client.get('/genres', queryParameters: {'mediaType': mediaType});
    return (data['genres'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(Genre.fromJson)
        .toList(growable: false);
  }
  Future<List<MediaItem>> recommendations(int id, {String mediaType = 'movie', int page = 1}) =>
      _list(ApiEndpoints.recommendations(id), query: {'mediaType': mediaType, 'page': page});
  Future<List<MediaItem>> similar(int id, {String mediaType = 'movie', int page = 1}) =>
      _list(ApiEndpoints.similar(id), query: {'mediaType': mediaType, 'page': page});
}
