import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/responsive/responsive_layout.dart';
import '../../models/media_item.dart';
import '../../providers/catalog_providers.dart';
import '../../shared/widgets/media/media_grid.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _debouncedQuery = '';
  String _filter = 'all';

  static const _suggestions = [
    'Action movies',
    'Comedy',
    'Drama series',
    'Horror',
    'Anime',
    'Science fiction',
    'Crime shows',
    'Family movies',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || _debouncedQuery.trim().length < 2) return;
    if (_scrollController.position.extentAfter < 900) {
      ref.read(searchResultsProvider(_debouncedQuery).notifier).loadMore();
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  void _applySuggestion(String value) {
    _debounce?.cancel();
    _textController.text = value;
    setState(() {
      _query = value;
      _debouncedQuery = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultsProvider(_debouncedQuery));
    final filteredItems = _filterItems(searchState.items);
    final padding = ResponsiveLayout.horizontalPadding(context);
    final showSuggestions = _query.trim().length < 2;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          cacheExtent: 1400,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(padding, 22, padding, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Search',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _textController,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      onSubmitted: (value) {
                        _debounce?.cancel();
                        setState(() => _debouncedQuery = value.trim());
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        hintText: 'Search movies and TV shows',
                        filled: true,
                        fillColor: AppColors.surfaceRaised,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FilterBar(
                      selected: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                    ),
                    const SizedBox(height: 18),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: showSuggestions
                          ? _SuggestionWrap(
                              key: const ValueKey('suggestions'),
                              suggestions: _suggestions,
                              onSelected: _applySuggestion,
                            )
                          : Text(
                              '${filteredItems.length} results',
                              key: const ValueKey('count'),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (!showSuggestions && searchState.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Text(searchState.error.toString()),
                ),
              )
            else if (!showSuggestions && !searchState.isLoading && filteredItems.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(padding),
                  child: Text(
                    'No matches found.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              MediaGrid(
                items: filteredItems,
                isLoading: !showSuggestions && searchState.isLoading && searchState.items.isEmpty,
                isLoadingMore: searchState.isLoadingMore,
                onNearEnd: () => ref.read(searchResultsProvider(_debouncedQuery).notifier).loadMore(),
              ),
          ],
        ),
      ),
    );
  }

  List<MediaItem> _filterItems(List<MediaItem> items) {
    return switch (_filter) {
      'movie' => items.where((item) => item.mediaType == 'movie').toList(growable: false),
      'tv' => items.where((item) => item.mediaType == 'tv').toList(growable: false),
      _ => items,
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterButton(label: 'All', value: 'all', selected: selected == 'all', onChanged: onChanged),
        _FilterButton(label: 'Movies', value: 'movie', selected: selected == 'movie', onChanged: onChanged),
        _FilterButton(label: 'TV Shows', value: 'tv', selected: selected == 'tv', onChanged: onChanged),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      selectedColor: AppColors.netflixRed,
      backgroundColor: AppColors.surfaceRaised,
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    );
  }
}

class _SuggestionWrap extends StatelessWidget {
  const _SuggestionWrap({
    super.key,
    required this.suggestions,
    required this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final suggestion in suggestions)
          ActionChip(
            avatar: const Icon(Icons.search_rounded, size: 18),
            label: Text(suggestion),
            onPressed: () => onSelected(suggestion),
            backgroundColor: AppColors.surfaceRaised,
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
      ],
    );
  }
}
