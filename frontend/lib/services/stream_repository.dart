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

  Future<StreamSource> movie(int id) async {
    return StreamSource.fromJson(await _client.get(ApiEndpoints.movieStream(id)));
  }

  Future<StreamSource> tv(int id, int season, int episode) async {
    return StreamSource.fromJson(await _client.get(ApiEndpoints.tvStream(id, season, episode)));
  }

  Future<TvSeason> tvSeason(int id, int season) async {
    return TvSeason.fromJson(await _client.get(ApiEndpoints.tvSeason(id, season)));
  }
}
