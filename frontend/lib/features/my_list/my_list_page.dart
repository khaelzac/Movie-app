import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../services/local_library_repository.dart';
import '../../shared/widgets/media/continue_watching_rail.dart';
import '../../shared/widgets/media/movie_rail.dart';

class MyListPage extends ConsumerWidget {
  const MyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryControllerProvider);
    final libraryController = ref.read(libraryControllerProvider.notifier);
    final padding = ResponsiveLayout.horizontalPadding(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          cacheExtent: 1200,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 26, padding, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My List',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Saved locally on this device.',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            if (library.isLoading)
              const SliverToBoxAdapter(child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())))
            else if (library.favorites.isEmpty && library.progress.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Text(
                    'Favorites and continue watching items will appear here.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: ContinueWatchingRail(
                  items: library.progress,
                  onClear: libraryController.clearProgress,
                ),
              ),
              SliverToBoxAdapter(
                child: MovieRail(
                  title: 'Favorites',
                  items: library.favorites,
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }
}
