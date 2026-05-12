import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../models/media_details.dart';
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
    );
    final source = ref.watch(streamSourceProvider(request));

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: source.when(
          data: (source) {
            _controller ??= WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setBackgroundColor(Colors.black)
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageStarted: (_) => setState(() => _loading = true),
                  onPageFinished: (_) => setState(() => _loading = false),
                ),
              )
              ..loadRequest(Uri.parse(source.url));

            return Stack(
              fit: StackFit.expand,
              children: [
                WebViewWidget(controller: _controller!),
                if (_loading)
                  const ColoredBox(
                    color: Colors.black,
                    child: Center(child: CircularProgressIndicator(color: AppColors.netflixRed)),
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
                                backgroundColor: Colors.black.withValues(alpha: 0.62),
                                foregroundColor: Colors.white,
                              ),
                            ),
                            if (widget.mediaType == 'tv')
                              FilledButton.icon(
                                onPressed: _nextEpisode,
                                icon: const Icon(Icons.skip_next_rounded),
                                label: const Text('Next Episode'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.black.withValues(alpha: 0.62),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (error, _) => _PlaybackError(message: error.toString()),
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.netflixRed)),
        ),
      ),
    );
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
            const Icon(Icons.error_outline_rounded, color: AppColors.netflixRed, size: 48),
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
