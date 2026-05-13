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
    final providers = ref.watch(streamProvidersProvider);
    final providerOptions =
        providers.valueOrNull ?? const <StreamProviderInfo>[];
    final configuredProviders = providerOptions
        .where((provider) => provider.configured)
        .toList(growable: false);
    final selectedProvider = _selectedProvider == null
        ? null
        : _providerById(configuredProviders, _selectedProvider!);
    final effectiveProvider = selectedProvider ??
        (configuredProviders.isEmpty ? null : configuredProviders.first);

    if (providers.isLoading && providerOptions.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: CircularProgressIndicator(color: AppColors.netflixRed)),
      );
    }

    if (providers.hasError ||
        providerOptions.isEmpty ||
        effectiveProvider == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _PlaybackError(
              message: providers.hasError
                  ? 'The server list could not be loaded. Check the backend URL and Vercel environment variables.'
                  : 'No configured playback servers were found. Add provider names and base URLs in the backend environment, then redeploy.',
              onRetry: () => ref.invalidate(streamProvidersProvider),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _ServerSwitcher(
                    providers: providerOptions,
                    selectedProvider: _selectedProvider ?? '',
                    isLoading: providers.isLoading,
                    errorMessage: providerOptions.isEmpty
                        ? 'No servers configured.'
                        : null,
                    onSelected: (provider) {
                      setState(() {
                        _selectedProvider = provider;
                        _loadedUrl = null;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final request = StreamRequest(
      mediaType: widget.mediaType,
      id: widget.id,
      season: widget.season,
      episode: widget.episode,
      provider: effectiveProvider.id,
    );
    final source = ref.watch(streamSourceProvider(request));

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
                        errorMessage: providers.hasError
                            ? 'Server list could not be refreshed.'
                            : null,
                        onSelected: (provider) {
                          if (provider == source.provider) return;
                          setState(() {
                            _selectedProvider = provider;
                            _loadedUrl = null;
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
          error: (error, _) => Stack(
            fit: StackFit.expand,
            children: [
              _PlaybackError(
                message: _friendlyPlaybackMessage(error),
                onRetry: () => ref.invalidate(streamSourceProvider(request)),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: _ServerSwitcher(
                      providers: providerOptions,
                      selectedProvider: effectiveProvider.id,
                      isLoading: providers.isLoading,
                      errorMessage: providers.hasError
                          ? 'Server list could not be loaded.'
                          : null,
                      onSelected: (provider) {
                        if (provider == effectiveProvider.id) return;
                        setState(() {
                          _selectedProvider = provider;
                          _loadedUrl = null;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.netflixRed)),
        ),
      ),
    );
  }

  String _friendlyPlaybackMessage(Object error) {
    final raw = error.toString();
    if (raw.contains('501') ||
        raw.toLowerCase().contains('disabled or unsupported')) {
      return 'This server is not configured for playback. Pick another server or update the backend environment variables.';
    }
    if (raw.toLowerCase().contains('socket') ||
        raw.toLowerCase().contains('timeout') ||
        raw.toLowerCase().contains('connection')) {
      return 'This server did not respond. Try another server.';
    }
    return 'This server could not start playback. Try another server.';
  }

  StreamProviderInfo? _providerById(
      List<StreamProviderInfo> providers, String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
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
    this.errorMessage,
    required this.onSelected,
  });

  final List<StreamProviderInfo> providers;
  final String selectedProvider;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final visibleProviders = providers
        .where((provider) => provider.id.isNotEmpty)
        .toList(growable: false);
    if (visibleProviders.isEmpty && !isLoading && errorMessage == null) {
      return const SizedBox.shrink();
    }

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
              if (errorMessage != null && visibleProviders.isEmpty)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Text(
                    errorMessage!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              for (final provider in visibleProviders)
                ChoiceChip(
                  label: Text(
                    provider.configured
                        ? (provider.name.isEmpty ? provider.id : provider.name)
                        : '${provider.name.isEmpty ? provider.id : provider.name} (not configured)',
                  ),
                  selected: provider.id == selectedProvider,
                  selectedColor: AppColors.netflixRed,
                  backgroundColor:
                      AppColors.surfaceRaised.withValues(alpha: 0.92),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: provider.configured
                            ? Colors.white
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  onSelected: provider.configured
                      ? (_) => onSelected(provider.id)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  const _PlaybackError({
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
