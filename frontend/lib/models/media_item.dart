class MediaItem {
  const MediaItem({
    required this.id,
    required this.title,
    required this.mediaType,
    this.overview = '',
    this.posterPath,
    this.backdropPath,
    String? posterUrl,
    String? backdropUrl,
    this.voteAverage = 0,
  })  : _posterUrl = posterUrl,
        _backdropUrl = backdropUrl;

  final int id;
  final String title;
  final String mediaType;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final String? _posterUrl;
  final String? _backdropUrl;
  final double voteAverage;

  String get posterUrl => _posterUrl ?? '';
  String get backdropUrl => _backdropUrl ?? '';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'mediaType': mediaType,
      'overview': overview,
      'posterPath': posterPath,
      'backdropPath': backdropPath,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'voteAverage': voteAverage,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final mediaType = json['mediaType'] as String? ?? json['media_type'] as String? ?? (json['name'] != null ? 'tv' : 'movie');
    return MediaItem(
      id: json['id'] as int,
      title: (json['title'] ?? json['name'] ?? 'Untitled') as String,
      mediaType: mediaType,
      overview: (json['overview'] ?? '') as String,
      posterPath: (json['posterPath'] ?? json['poster_path']) as String?,
      backdropPath: (json['backdropPath'] ?? json['backdrop_path']) as String?,
      posterUrl: json['posterUrl'] as String?,
      backdropUrl: json['backdropUrl'] as String?,
      voteAverage: ((json['voteAverage'] ?? json['vote_average'] ?? 0) as num).toDouble(),
    );
  }
}
