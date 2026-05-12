class ApiEndpoints {
  const ApiEndpoints._();

  static const trending = '/trending';
  static const popularMovies = '/movies/popular';
  static const popularTv = '/tv/popular';
  static const topRated = '/top-rated';
  static const search = '/search';

  static String movieDetails(int id) => '/movie/$id';
  static String tvDetails(int id) => '/tv/$id';
  static String tvSeason(int id, int season) => '/tv/$id/season/$season';
  static String movieStream(int id) => '/stream/movie/$id';
  static String tvStream(int id, int season, int episode) => '/stream/tv/$id/$season/$episode';
  static String genre(String slug) => '/genres/$slug';
  static String recommendations(int id) => '/recommendations/$id';
  static String similar(int id) => '/similar/$id';
}
