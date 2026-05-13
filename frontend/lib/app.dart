import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/navigation/tv_shortcuts.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class OcampoFlixApp extends ConsumerWidget {
  const OcampoFlixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return TvShortcuts(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: AppConstants.appName,
        theme: AppTheme.dark,
        routerConfig: router,
      ),
    );
  }
}
