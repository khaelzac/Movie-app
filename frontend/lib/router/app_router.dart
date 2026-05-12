import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/app_routes.dart';
import '../features/catalog/catalog_page.dart';
import '../features/details/movie_details_page.dart';
import '../features/details/tv_details_page.dart';
import '../features/home/home_page.dart';
import '../features/my_list/my_list_page.dart';
import '../features/playback/playback_page.dart';
import '../features/profiles/profile_selection_page.dart';
import '../features/search/search_page.dart';
import '../features/settings/settings_page.dart';
import '../features/splash/splash_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.profiles, builder: (_, __) => const ProfileSelectionPage()),
      GoRoute(path: AppRoutes.home, builder: (_, __) => const HomePage()),
      GoRoute(
        path: '/movie/:id',
        pageBuilder: (_, state) => _detailsPage(
          state,
          MovieDetailsPage(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/tv/:id',
        pageBuilder: (_, state) => _detailsPage(
          state,
          TvDetailsPage(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(path: AppRoutes.search, builder: (_, __) => const SearchPage()),
      GoRoute(
        path: '/play/:mediaType/:id',
        pageBuilder: (_, state) => _detailsPage(
          state,
          PlaybackPage(
            mediaType: state.pathParameters['mediaType']!,
            id: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            title: state.uri.queryParameters['title'] ?? 'Playback',
            posterUrl: state.uri.queryParameters['posterUrl'] ?? '',
            backdropUrl: state.uri.queryParameters['backdropUrl'] ?? '',
            season: int.tryParse(state.uri.queryParameters['season'] ?? ''),
            episode: int.tryParse(state.uri.queryParameters['episode'] ?? ''),
          ),
        ),
      ),
      GoRoute(path: '/catalog/:type', builder: (_, state) => CatalogPage(type: state.pathParameters['type']!)),
      GoRoute(path: AppRoutes.myList, builder: (_, __) => const MyListPage()),
      GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsPage()),
    ],
  );
});

CustomTransitionPage<void> _detailsPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0.035, 0), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}
