class StreamSource {
  const StreamSource({
    required this.url,
    required this.provider,
    this.referer = '',
    this.subtitles = const [],
    this.mediaType = '',
    this.tmdbId = 0,
    this.season,
    this.episode,
  });

  final String url;
  final String provider;
  final String referer;
  final List<StreamSubtitle> subtitles;
  final String mediaType;
  final int tmdbId;
  final int? season;
  final int? episode;

  factory StreamSource.fromJson(Map<String, dynamic> json) {
    return StreamSource(
      url: (json['streamUrl'] ?? json['url'] ?? '') as String,
      provider: (json['provider'] ?? '') as String,
      referer: (json['referer'] ?? '') as String,
      subtitles: (json['subtitles'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(StreamSubtitle.fromJson)
          .where((subtitle) => subtitle.url.isNotEmpty)
          .toList(growable: false),
      mediaType: (json['mediaType'] ?? '') as String,
      tmdbId: (json['tmdbId'] as num?)?.toInt() ?? 0,
      season: (json['season'] as num?)?.toInt(),
      episode: (json['episode'] as num?)?.toInt(),
    );
  }
}

class StreamSubtitle {
  const StreamSubtitle({
    required this.url,
    this.label = 'Subtitle',
    this.language,
    this.kind = 'subtitles',
  });

  final String url;
  final String label;
  final String? language;
  final String kind;

  factory StreamSubtitle.fromJson(Map<String, dynamic> json) {
    final language = json['language'] as String?;
    return StreamSubtitle(
      url: (json['url'] ?? '') as String,
      label: (json['label'] ?? language ?? 'Subtitle') as String,
      language: language,
      kind: (json['kind'] ?? 'subtitles') as String,
    );
  }
}

class StreamProviderInfo {
  const StreamProviderInfo({
    required this.id,
    required this.name,
    this.configured = true,
  });

  final String id;
  final String name;
  final bool configured;

  factory StreamProviderInfo.fromJson(Map<String, dynamic> json) {
    return StreamProviderInfo(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      configured: json['configured'] as bool? ?? true,
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
