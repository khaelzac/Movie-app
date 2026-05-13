import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../models/media_details.dart';
import '../../models/stream_source.dart';
import '../../providers/catalog_providers.dart';
import '../../services/local_library_repository.dart';

class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({
    super.key,
    required this.mediaType,
    required this.id,
    required this.title,
    this.posterUrl = '',
    this.backdropUrl = '',
    this.season,
    this.episode,
  });

  final String mediaType;
  final int id;
  final String title;
  final String posterUrl;
  final String backdropUrl;
  final int? season;
  final int? episode;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  WebViewController? _controller;
  bool _loading = true;
  String? _loadedUrl;
  String? _selectedProvider;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final request = StreamRequest(
      mediaType: widget.mediaType,
      id: widget.id,
      season: widget.season,
      episode: widget.episode,
      provider: _selectedProvider,
    );
    final source = ref.watch(streamSourceProvider(request));
    final providers = ref.watch(streamProvidersProvider);

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: source.when(
          data: (source) {
            final controller = _loadSource(source.url);

            return Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: controller),
                if (_loading)
                  const ColoredBox(
                    color: Colors.black,
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.netflixRed)),
                  ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: FocusTraversalGroup(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: 'Back',
                            ),
                            FilledButton.icon(
                              onPressed: () => _saveProgress(),
                              icon: const Icon(Icons.bookmark_rounded),
                              label: const Text('Save Progress'),
                              style: FilledButton.styleFrom(
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.62),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            if (widget.mediaType == 'tv')
                              FilledButton.icon(
                                onPressed: _nextEpisode,
                                icon: const Icon(Icons.skip_next_rounded),
                                label: const Text('Next Episode'),
                                style: FilledButton.styleFrom(
                                  backgroundColor:
                                      Colors.black.withValues(alpha: 0.62),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: _ServerSwitcher(
                        providers: providers.valueOrNull ??
                            [
                              StreamProviderInfo(
                                  id: source.provider, name: source.provider)
                            ],
                        selectedProvider: source.provider,
                        isLoading: providers.isLoading,
                        onSelected: (provider) {
                          if (provider == source.provider) return;
                          setState(() {
                            _selectedProvider = provider;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (error, _) => _PlaybackError(message: error.toString()),
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.netflixRed)),
        ),
      ),
    );
  }

  WebViewController _loadSource(String url) {
    final controller = _controller ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      );

    if (_loadedUrl != url) {
      _loadedUrl = url;
      _loading = true;
      controller.loadRequest(Uri.parse(url));
    }

    return controller;
  }

  Future<void> _saveProgress() async {
    await ref.read(libraryControllerProvider.notifier).saveProgress(
          _detailsShell(),
          positionSeconds: 420,
          durationSeconds: 3600,
          season: widget.season,
          episode: widget.episode,
        );
  }

  void _nextEpisode() {
    final season = widget.season ?? 1;
    final episode = (widget.episode ?? 1) + 1;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PlaybackPage(
          mediaType: 'tv',
          id: widget.id,
          title: widget.title,
          posterUrl: widget.posterUrl,
          backdropUrl: widget.backdropUrl,
          season: season,
          episode: episode,
        ),
      ),
    );
  }

  MediaDetails _detailsShell() {
    return MediaDetails(
      id: widget.id,
      mediaType: widget.mediaType,
      title: widget.title,
      posterUrl: widget.posterUrl,
      backdropUrl: widget.backdropUrl,
    );
  }
}

class _ServerSwitcher extends StatelessWidget {
  const _ServerSwitcher({
    required this.providers,
    required this.selectedProvider,
    required this.isLoading,
    required this.onSelected,
  });

  final List<StreamProviderInfo> providers;
  final String selectedProvider;
  final bool isLoading;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleProviders = providers
        .where((provider) => provider.id.isNotEmpty)
        .toList(growable: false);
    if (visibleProviders.isEmpty && !isLoading) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: FocusTraversalGroup(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Servers',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.netflixRed),
                ),
              for (final provider in visibleProviders)
                ChoiceChip(
                  label:
                      Text(provider.name.isEmpty ? provider.id : provider.name),
                  selected: provider.id == selectedProvider,
                  selectedColor: AppColors.netflixRed,
                  backgroundColor:
                      AppColors.surfaceRaised.withValues(alpha: 0.92),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  onSelected: (_) => onSelected(provider.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.netflixRed, size: 48),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
