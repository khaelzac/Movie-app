import 'dart:async';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  BetterPlayerController? _playerController;
  StreamRequest? _activeRequest;
  String? _activeUrl;
  String? _selectedProvider;
  String? _playbackError;
  bool _isPreparing = true;
  bool _isBuffering = false;
  bool _controlsVisible = true;
  int _retryCount = 0;
  Timer? _controlsTimer;

  static const _maxRetriesPerProvider = 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _scheduleControlsHide();
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _disposePlayer();
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
    final effectiveProvider =
        selectedProvider ?? _defaultPlaybackProvider(configuredProviders);

    if (providers.isLoading && providerOptions.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.netflixRed),
        ),
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
            _bottomServerSwitcher(providerOptions, '', providers.isLoading),
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
            final controller = _preparePlayer(source, request);

            return Stack(
              fit: StackFit.expand,
              children: [
                Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _showControlsTemporarily(),
                  child: Center(
                    child: BetterPlayer(controller: controller),
                  ),
                ),
                if (_isPreparing || _isBuffering)
                  _LoadingOverlay(
                    message: _isPreparing ? 'Loading stream...' : 'Buffering...',
                  ),
                if (_playbackError != null)
                  ColoredBox(
                    color: Colors.black,
                    child: _PlaybackError(
                      message: _playbackError!,
                      onRetry: () => _retryCurrentProvider(request),
                    ),
                  ),
                if (_playbackError != null)
                  _bottomServerSwitcher(
                    providerOptions,
                    effectiveProvider.id,
                    providers.isLoading,
                    request: request,
                  ),
                AnimatedOpacity(
                  opacity: _controlsVisible ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_controlsVisible,
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: _PlaybackControls(
                            mediaType: widget.mediaType,
                            onBack: () => Navigator.of(context).maybePop(),
                            onServers: () => _showServerSheet(
                              context,
                              providers.valueOrNull ??
                                  const <StreamProviderInfo>[],
                              source.provider,
                            ),
                            onSaveProgress: _saveProgress,
                            onNextEpisode:
                                widget.mediaType == 'tv' ? _nextEpisode : null,
                          ),
                        ),
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
              _bottomServerSwitcher(
                providerOptions,
                effectiveProvider.id,
                providers.isLoading,
                request: request,
              ),
            ],
          ),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.netflixRed),
          ),
        ),
      ),
    );
  }

  BetterPlayerController _preparePlayer(
    StreamSource source,
    StreamRequest request,
  ) {
    if (_activeUrl == source.url && _playerController != null) {
      return _playerController!;
    }

    _disposePlayer();
    _activeRequest = request;
    _activeUrl = source.url;
    _retryCount = 0;
    _isPreparing = true;
    _isBuffering = false;
    _playbackError = null;

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      source.url,
      videoFormat: BetterPlayerVideoFormat.hls,
      headers: _headersFor(source),
      subtitles: _subtitleSources(source),
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: true,
        preCacheSize: 10 * 1024 * 1024,
        maxCacheSize: 100 * 1024 * 1024,
        maxCacheFileSize: 30 * 1024 * 1024,
      ),
    );

    final controller = BetterPlayerController(
      BetterPlayerConfiguration(
        autoPlay: true,
        fit: BoxFit.contain,
        aspectRatio: 16 / 9,
        fullScreenByDefault: false,
        autoDetectFullscreenDeviceOrientation: true,
        autoDetectFullscreenAspectRatio: true,
        allowedScreenSleep: false,
        handleLifecycle: true,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          enableFullscreen: true,
          enablePlaybackSpeed: true,
          enableSubtitles: source.subtitles.isNotEmpty,
          enableQualities: true,
          enableAudioTracks: true,
          loadingColor: AppColors.netflixRed,
          progressBarPlayedColor: AppColors.netflixRed,
          progressBarHandleColor: AppColors.netflixRed,
          controlBarColor: Colors.black.withValues(alpha: 0.72),
          iconsColor: Colors.white,
          textColor: Colors.white,
        ),
        errorBuilder: (context, errorMessage) => _PlaybackError(
          message: _friendlyPlaybackMessage(errorMessage ?? 'Playback failed.'),
          onRetry: () => _retryCurrentProvider(request),
        ),
      ),
      betterPlayerDataSource: dataSource,
    );

    controller.addEventsListener(_onPlayerEvent);
    _playerController = controller;
    return controller;
  }

  Map<String, String> _headersFor(StreamSource source) {
    final headers = <String, String>{
      'Accept': 'application/vnd.apple.mpegurl,application/x-mpegURL,*/*',
    };
    if (source.referer.isNotEmpty) {
      headers['Referer'] = source.referer;
      final origin = Uri.tryParse(source.referer)?.origin;
      if (origin != null) headers['Origin'] = origin;
    }
    return headers;
  }

  List<BetterPlayerSubtitlesSource> _subtitleSources(StreamSource source) {
    return source.subtitles
        .map((subtitle) => BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: subtitle.label,
              urls: [subtitle.url],
            ))
        .toList(growable: false);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        setState(() {
          _isPreparing = false;
          _isBuffering = false;
          _playbackError = null;
        });
        _scheduleControlsHide();
        break;
      case BetterPlayerEventType.bufferingStart:
        setState(() => _isBuffering = true);
        break;
      case BetterPlayerEventType.bufferingEnd:
        setState(() => _isBuffering = false);
        break;
      case BetterPlayerEventType.exception:
        _handlePlaybackFailure();
        break;
      default:
        break;
    }
  }

  void _handlePlaybackFailure() {
    if (!mounted) return;

    final request = _activeRequest;
    if (request != null && _retryCount < _maxRetriesPerProvider) {
      _retryCount += 1;
      ref.invalidate(streamSourceProvider(request));
      return;
    }

    final providers = ref.read(streamProvidersProvider).valueOrNull ??
        const <StreamProviderInfo>[];
    final configuredProviders = providers
        .where((provider) => provider.configured)
        .toList(growable: false);
    final nextProvider = _nextProvider(configuredProviders);

    if (nextProvider != null) {
      setState(() {
        _selectedProvider = nextProvider.id;
        _activeUrl = null;
        _playbackError = null;
        _isPreparing = true;
      });
      return;
    }

    setState(() {
      _isPreparing = false;
      _isBuffering = false;
      _playbackError =
          'Native playback could not start this HLS stream. Try another server or check the backend stream resolver.';
    });
  }

  void _retryCurrentProvider(StreamRequest request) {
    setState(() {
      _activeUrl = null;
      _playbackError = null;
      _isPreparing = true;
      _isBuffering = false;
    });
    ref.invalidate(streamSourceProvider(request));
  }

  void _disposePlayer() {
    final controller = _playerController;
    if (controller == null) return;
    controller.removeEventsListener(_onPlayerEvent);
    controller.dispose();
    _playerController = null;
  }

  Widget _bottomServerSwitcher(
    List<StreamProviderInfo> providers,
    String selectedProvider,
    bool isLoading, {
    StreamRequest? request,
  }) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: _ServerSwitcher(
            providers: providers,
            selectedProvider: selectedProvider,
            isLoading: isLoading,
            errorMessage: providers.isEmpty ? 'No servers configured.' : null,
            onSelected: (provider) {
              if (provider == selectedProvider) return;
              setState(() {
                _selectedProvider = provider;
                _activeUrl = null;
                _playbackError = null;
                _isPreparing = true;
              });
              if (request != null) {
                ref.invalidate(streamSourceProvider(request));
              }
            },
          ),
        ),
      ),
    );
  }

  void _showControlsTemporarily() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isPreparing || _isBuffering || _playbackError != null) {
        return;
      }
      setState(() => _controlsVisible = false);
    });
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
    if (raw.toLowerCase().contains('m3u8') ||
        raw.toLowerCase().contains('hls')) {
      return 'This server did not return a playable HLS stream. Try another server.';
    }
    return 'This server could not start native playback. Try another server.';
  }

  StreamProviderInfo? _providerById(
      List<StreamProviderInfo> providers, String id) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  StreamProviderInfo? _defaultPlaybackProvider(
      List<StreamProviderInfo> providers) {
    const preferredProviderIds = ['env-8', 'env-2', 'env-1', 'env-9'];

    for (final providerId in preferredProviderIds) {
      final provider = _providerById(providers, providerId);
      if (provider != null) return provider;
    }

    return providers.isEmpty ? null : providers.first;
  }

  StreamProviderInfo? _nextProvider(List<StreamProviderInfo> providers) {
    if (providers.length < 2) return null;

    final currentId = _selectedProvider ?? _activeRequest?.provider;
    final currentIndex =
        providers.indexWhere((provider) => provider.id == currentId);
    if (currentIndex < 0) return providers.first;

    final nextIndex = currentIndex + 1;
    if (nextIndex >= providers.length) return null;
    return providers[nextIndex];
  }

  void _showServerSheet(
    BuildContext context,
    List<StreamProviderInfo> providers,
    String selectedProvider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) {
        final visibleProviders = providers
            .where((provider) => provider.id.isNotEmpty)
            .toList(growable: false);

        final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
              physics: const ClampingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servers',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  if (visibleProviders.isEmpty)
                    Text(
                      'No servers configured.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textMuted),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final provider in visibleProviders)
                          ChoiceChip(
                            label: Text(provider.configured
                                ? (provider.name.isEmpty
                                    ? provider.id
                                    : provider.name)
                                : '${provider.name.isEmpty ? provider.id : provider.name} (not configured)'),
                            selected: provider.id == selectedProvider,
                            selectedColor: AppColors.netflixRed,
                            backgroundColor: AppColors.surfaceRaised,
                            labelStyle: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: provider.configured
                                      ? Colors.white
                                      : AppColors.textMuted,
                                  fontWeight: FontWeight.w800,
                                ),
                            onSelected: provider.configured
                                ? (_) {
                                    Navigator.of(context).pop();
                                    if (provider.id == selectedProvider) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedProvider = provider.id;
                                      _activeUrl = null;
                                      _playbackError = null;
                                      _isPreparing = true;
                                    });
                                  }
                                : null,
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProgress() async {
    final position =
        await _playerController?.videoPlayerController?.position;
    final duration =
        _playerController?.videoPlayerController?.value.duration;

    await ref.read(libraryControllerProvider.notifier).saveProgress(
          _detailsShell(),
          positionSeconds: position?.inSeconds ?? 0,
          durationSeconds: duration?.inSeconds ?? 0,
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

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.74),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.netflixRed),
            const SizedBox(height: 14),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
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
                    strokeWidth: 2,
                    color: AppColors.netflixRed,
                  ),
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

class _PlaybackControls extends StatelessWidget {
  const _PlaybackControls({
    required this.mediaType,
    required this.onBack,
    required this.onServers,
    required this.onSaveProgress,
    this.onNextEpisode,
  });

  final String mediaType;
  final VoidCallback onBack;
  final VoidCallback onServers;
  final VoidCallback onSaveProgress;
  final VoidCallback? onNextEpisode;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          FilledButton.icon(
            onPressed: onServers,
            icon: const Icon(Icons.dns_rounded),
            label: const Text('Servers'),
            style: _buttonStyle(context),
          ),
          FilledButton.icon(
            onPressed: onSaveProgress,
            icon: const Icon(Icons.bookmark_rounded),
            label: const Text('Save Progress'),
            style: _buttonStyle(context),
          ),
          if (mediaType == 'tv' && onNextEpisode != null)
            FilledButton.icon(
              onPressed: onNextEpisode,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Next Episode'),
              style: _buttonStyle(context),
            ),
        ],
      ),
    );
  }

  ButtonStyle _buttonStyle(BuildContext context) {
    return FilledButton.styleFrom(
      backgroundColor: Colors.black.withValues(alpha: 0.62),
      foregroundColor: Colors.white,
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
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.netflixRed,
              size: 48,
            ),
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
