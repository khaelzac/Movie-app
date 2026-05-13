import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/api_endpoints.dart';
import '../models/stream_source.dart';
import 'api_service.dart';

final streamRepositoryProvider = Provider<StreamRepository>((ref) {
  return StreamRepository(ref.watch(apiServiceProvider));
});

class StreamRepository {
  const StreamRepository(this._client);

  final ApiService _client;

  Future<List<StreamProviderInfo>> providers() async {
    final data = await _client.get(ApiEndpoints.streamProviders);
    return (data['providers'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StreamProviderInfo.fromJson)
        .where((provider) => provider.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<StreamSource> movie(int id, {String? provider}) async {
    return StreamSource.fromJson(
        await _client.get(ApiEndpoints.movieStream(id, provider: provider)));
  }

  Future<StreamSource> tv(int id, int season, int episode,
      {String? provider}) async {
    return StreamSource.fromJson(await _client
        .get(ApiEndpoints.tvStream(id, season, episode, provider: provider)));
  }

  Future<TvSeason> tvSeason(int id, int season) async {
    return TvSeason.fromJson(
        await _client.get(ApiEndpoints.tvSeason(id, season)));
  }
}
