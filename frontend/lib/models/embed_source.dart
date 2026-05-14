class EmbedSource {
  const EmbedSource({
    required this.embedUrl,
    required this.provider,
  });

  final String embedUrl;
  final String provider;

  factory EmbedSource.fromJson(Map<String, dynamic> json) {
    return EmbedSource(
      embedUrl: (json['embedUrl'] ?? '') as String,
      provider: (json['provider'] ?? '') as String,
    );
  }
}

class EmbedProviderInfo {
  const EmbedProviderInfo({
    required this.id,
    required this.name,
    this.configured = true,
    this.enabled = true,
    this.healthScore = 0,
  });

  final String id;
  final String name;
  final bool configured;
  final bool enabled;
  final int healthScore;

  factory EmbedProviderInfo.fromJson(Map<String, dynamic> json) {
    return EmbedProviderInfo(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      configured: json['configured'] as bool? ?? true,
      enabled: json['enabled'] as bool? ?? true,
      healthScore: (json['healthScore'] as num?)?.toInt() ?? 0,
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
