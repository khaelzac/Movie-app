import 'package:flutter/material.dart';

import 'app_routes.dart';

class NavItem {
  const NavItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

class AppNavigation {
  const AppNavigation._();

  static const primary = [
    NavItem(label: 'Home', icon: Icons.home_outlined, route: AppRoutes.home),
    NavItem(label: 'Search', icon: Icons.search, route: AppRoutes.search),
    NavItem(label: 'Trending', icon: Icons.local_fire_department_outlined, route: AppRoutes.trending),
    NavItem(label: 'Popular', icon: Icons.movie_outlined, route: AppRoutes.popular),
    NavItem(label: 'My List', icon: Icons.add, route: AppRoutes.myList),
    NavItem(label: 'Settings', icon: Icons.settings_outlined, route: AppRoutes.settings),
  ];
}
