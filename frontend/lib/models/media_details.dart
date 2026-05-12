import 'media_item.dart';

class MediaDetails {
  const MediaDetails({
    required this.id,
    required this.mediaType,
    required this.title,
    this.overview = '',
    this.tagline = '',
    this.posterUrl = '',
    this.backdropUrl = '',
    this.releaseDate,
    this.runtime,
    this.episodeRunTime = const [],
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.genres = const [],
    this.voteAverage = 0,
    this.voteCount = 0,
    this.status,
    this.cast = const [],
    this.recommendations = const [],
    this.similar = const [],
  });

  final int id;
  final String mediaType;
  final String title;
  final String overview;
  final String tagline;
  final String posterUrl;
  final String backdropUrl;
  final String? releaseDate;
  final int? runtime;
  final List<int> episodeRunTime;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<Genre> genres;
  final double voteAverage;
  final int voteCount;
  final String? status;
  final List<CastMember> cast;
  final List<MediaItem> recommendations;
  final List<MediaItem> similar;

  String get year {
    if (releaseDate == null || releaseDate!.length < 4) return '';
    return releaseDate!.substring(0, 4);
  }

  String get runtimeLabel {
    if (runtime != null && runtime! > 0) {
      final hours = runtime! ~/ 60;
      final minutes = runtime! % 60;
      return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
    }
    final episodeRuntime = _firstOrNull(episodeRunTime.where((value) => value > 0));
    return episodeRuntime == null ? '' : '${episodeRuntime}m episodes';
  }

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      mediaType: mediaType,
      overview: overview,
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      voteAverage: voteAverage,
    );
  }

  factory MediaDetails.fromJson(Map<String, dynamic> json) {
    return MediaDetails(
      id: json['id'] as int,
      mediaType: json['mediaType'] as String? ?? 'movie',
      title: (json['title'] ?? 'Untitled') as String,
      overview: (json['overview'] ?? '') as String,
      tagline: (json['tagline'] ?? '') as String,
      posterUrl: (json['posterUrl'] ?? '') as String,
      backdropUrl: (json['backdropUrl'] ?? '') as String,
      releaseDate: json['releaseDate'] as String?,
      runtime: (json['runtime'] as num?)?.toInt(),
      episodeRunTime: (json['episodeRunTime'] as List<dynamic>? ?? []).whereType<num>().map((value) => value.toInt()).toList(),
      numberOfSeasons: (json['numberOfSeasons'] as num?)?.toInt(),
      numberOfEpisodes: (json['numberOfEpisodes'] as num?)?.toInt(),
      genres: (json['genres'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Genre.fromJson)
          .toList(growable: false),
      voteAverage: ((json['voteAverage'] ?? 0) as num).toDouble(),
      voteCount: ((json['voteCount'] ?? 0) as num).toInt(),
      status: json['status'] as String?,
      cast: (json['cast'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CastMember.fromJson)
          .toList(growable: false),
      recommendations: (json['recommendations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromJson)
          .toList(growable: false),
      similar: (json['similar'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MediaItem.fromJson)
          .toList(growable: false),
    );
  }
}

T? _firstOrNull<T>(Iterable<T> values) {
  final iterator = values.iterator;
  return iterator.moveNext() ? iterator.current : null;
}

class Genre {
  const Genre({required this.id, required this.name});

  final int id;
  final String name;

  factory Genre.fromJson(Map<String, dynamic> json) {
    return Genre(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '') as String,
    );
  }
}

class CastMember {
  const CastMember({
    required this.id,
    required this.name,
    this.character = '',
    this.profileUrl = '',
  });

  final int id;
  final String name;
  final String character;
  final String profileUrl;

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? 'Unknown') as String,
      character: (json['character'] ?? '') as String,
      profileUrl: (json['profileUrl'] ?? '') as String,
    );
  }
}
