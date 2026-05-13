class StreamSource {
  const StreamSource({
    required this.url,
    required this.provider,
    required this.mediaType,
    required this.tmdbId,
    this.season,
    this.episode,
  });

  final String url;
  final String provider;
  final String mediaType;
  final int tmdbId;
  final int? season;
  final int? episode;

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      url: (json['url'] ?? '') as String,
      provider: (json['provider'] ?? '') as String,
      mediaType: (json['mediaType'] ?? '') as String,
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
    );
  }
}

class StreamProviderInfo {
  const StreamProviderInfo({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory StreamProviderInfo.fromJson(Map<String, dynamic> json) {
    return StreamProviderInfo(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
    );
  }
}

class TvSeason {
  const TvSeason({
    required this.seasonNumber,
    required this.episodes,
    this.name = '',
    this.episodeCount = 0,
  });

  final int seasonNumber;
  final String name;
  final int episodeCount;
  final List<TvEpisode> episodes;

  factory TvSeason.fromJson(Map<String, dynamic> json) {
    return TvSeason(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      episodeCount: (json['episodeCount'] as num?)?.toInt() ?? 0,
      episodes: (json['episodes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TvEpisode.fromJson)
          .toList(growable: false),
    );
  }
}

class TvEpisode {
  const TvEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.name = '',
    this.overview = '',
    this.airDate,
    this.stillUrl = '',
    this.voteAverage = 0,
    this.runtime,
  });

  final int seasonNumber;
  final int episodeNumber;
  final String name;
  final String overview;
  final String? airDate;
  final String stillUrl;
  final double voteAverage;
  final int? runtime;

  factory TvEpisode.fromJson(Map<String, dynamic> json) {
    return TvEpisode(
      seasonNumber: (json['seasonNumber'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episodeNumber'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
      overview: (json['overview'] ?? '') as String,
      airDate: json['airDate'] as String?,
      stillUrl: (json['stillUrl'] ?? '') as String,
      voteAverage: ((json['voteAverage'] ?? 0) as num).toDouble(),
      runtime: (json['runtime'] as num?)?.toInt(),
    );
  }
}
