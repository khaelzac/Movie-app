class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const home = '/home';
  static const search = '/search';
  static const trending = '/catalog/trending';
  static const popular = '/catalog/popular';
  static const topRated = '/catalog/top-rated';
  static const genres = '/catalog/genres';
  static const myList = '/my-list';
  static const settings = '/settings';

  static String movie(String id) => '/movie/$id';
  static String tv(String id) => '/tv/$id';
  static String playMovie(String id, String title,
          {String posterUrl = '', String backdropUrl = ''}) =>
      '/play/movie/$id?title=${Uri.encodeComponent(title)}&posterUrl=${Uri.encodeComponent(posterUrl)}&backdropUrl=${Uri.encodeComponent(backdropUrl)}';
  static String playTv(String id, String title, int season, int episode,
          {String posterUrl = '', String backdropUrl = ''}) =>
      '/play/tv/$id?title=${Uri.encodeComponent(title)}&season=$season&episode=$episode&posterUrl=${Uri.encodeComponent(posterUrl)}&backdropUrl=${Uri.encodeComponent(backdropUrl)}';
  static String catalog(String type) => '/catalog/$type';
}
