class ApiEndpoints {
  const ApiEndpoints._();

  static const trending = '/trending';
  static const popularMovies = '/movies/popular';
  static const popularTv = '/tv/popular';
  static const topRated = '/top-rated';
  static const search = '/search';
  static const embedProviders = '/embed/providers';

  static String movieDetails(int id) => '/movie/$id';
  static String tvDetails(int id) => '/tv/$id';
  static String tvSeason(int id, int season) => '/tv/$id/season/$season';
  static String movieEmbed(int id, {String? provider}) {
    final query = provider == null || provider.isEmpty
        ? ''
        : '?provider=${Uri.encodeQueryComponent(provider)}';
    return '/embed/movie/$id$query';
  }

  static String tvEmbed(int id, int season, int episode, {String? provider}) {
    final query = provider == null || provider.isEmpty
        ? ''
        : '?provider=${Uri.encodeQueryComponent(provider)}';
    return '/embed/tv/$id/$season/$episode$query';
  }

  static String genre(String slug) => '/genres/$slug';
  static String recommendations(int id) => '/recommendations/$id';
  static String similar(int id) => '/similar/$id';
}
