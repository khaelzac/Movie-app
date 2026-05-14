import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../models/embed_source.dart';
import 'api_service.dart';

final embedRepositoryProvider = Provider<EmbedRepository>((ref) {
  return EmbedRepository(ref.watch(apiServiceProvider));
});

class EmbedRepository {
  const EmbedRepository(this._client);

  final ApiService _client;

  Future<List<EmbedProviderInfo>> providers() async {
    final data = await _client.get(ApiEndpoints.embedProviders);
    return (data['providers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(EmbedProviderInfo.fromJson)
        .where((provider) => provider.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<EmbedSource> movie(int id, {String? provider}) async {
    return _parseEmbedSource(await _client.get(
      ApiEndpoints.movieEmbed(id, provider: provider),
    ));
  }

  Future<EmbedSource> tv(
    int id,
    int season,
    int episode, {
    String? provider,
  }) async {
    return _parseEmbedSource(await _client.get(
      ApiEndpoints.tvEmbed(id, season, episode, provider: provider),
    ));
  }

  Future<TvSeason> tvSeason(int id, int season) async {
    return TvSeason.fromJson(
      await _client.get(ApiEndpoints.tvSeason(id, season)),
    );
  }

  EmbedSource _parseEmbedSource(Map<String, dynamic> data) {
    if (data['success'] == false) {
      throw const EmbedPlaybackException(
        'The backend rejected this embed request.',
      );
    }

    final source = EmbedSource.fromJson(data);
    final uri = Uri.tryParse(source.embedUrl);

    if (source.embedUrl.trim().isEmpty) {
      throw const EmbedPlaybackException(
        'The backend did not return an embed URL.',
      );
    }

    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const EmbedPlaybackException(
        'The backend returned an invalid embed URL.',
      );
    }

    if (uri.scheme != 'https') {
      throw const EmbedPlaybackException(
        'Embed playback must use HTTPS.',
      );
    }

    if (!uri.path.endsWith('/embed') && uri.path != '/embed') {
      throw const EmbedPlaybackException(
        'The backend did not return a Worker embed page.',
      );
    }

    if (!uri.queryParameters.containsKey('token')) {
      throw const EmbedPlaybackException(
        'The embed URL is missing its signed token.',
      );
    }

    return source;
  }
}

class EmbedPlaybackException implements Exception {
  const EmbedPlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}
