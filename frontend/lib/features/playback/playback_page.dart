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
  Timer? _startupTimer;
  Timer? _bufferingTimer;

  static const _maxRetriesPerProvider = 2;
  static const _startupTimeout = Duration(seconds: 22);
  static const _bufferingTimeout = Duration(seconds: 35);

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
    _startupTimer?.cancel();
    _bufferingTimer?.cancel();
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
      provider: selectedProvider?.id,
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
                    message:
                        _isPreparing ? 'Loading stream...' : 'Buffering...',
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
    _activeRequest = request.provider == null
        ? StreamRequest(
            mediaType: request.mediaType,
            id: request.id,
            season: request.season,
            episode: request.episode,
            provider: source.provider,
          )
        : request;
    _activeUrl = source.url;
    _retryCount = 0;
    _isPreparing = true;
    _isBuffering = false;
    _playbackError = null;
    _startStartupTimeout();

    final dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      source.url,
      videoFormat: BetterPlayerVideoFormat.hls,
      videoExtension: 'm3u8',
      headers: _headersFor(source),
      subtitles: _subtitleSources(source),
      useAsmsTracks: true,
      useAsmsAudioTracks: true,
      useAsmsSubtitles: true,
      cacheConfiguration: const BetterPlayerCacheConfiguration(
        useCache: false,
      ),
      bufferingConfiguration: const BetterPlayerBufferingConfiguration(
        minBufferMs: 12000,
        maxBufferMs: 50000,
        bufferForPlaybackMs: 1500,
        bufferForPlaybackAfterRebufferMs: 3000,
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
        eventListener: _onPlayerEvent,
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

    _playerController = controller;
    return controller;
  }

  Map<String, String> _headersFor(StreamSource source) {
    final headers = <String, String>{
      'Accept':
          'application/vnd.apple.mpegurl,application/x-mpegURL,application/vnd.apple.mpegurl,text/plain,*/*',
      'Accept-Language': 'en-US,en;q=0.9',
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
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
              headers: _headersFor(source),
            ))
        .toList(growable: false);
  }

  void _onPlayerEvent(BetterPlayerEvent event) {
    if (!mounted) return;

    switch (event.betterPlayerEventType) {
      case BetterPlayerEventType.initialized:
        _startupTimer?.cancel();
        _bufferingTimer?.cancel();
        setState(() {
          _isPreparing = false;
          _isBuffering = false;
          _playbackError = null;
        });
        _scheduleControlsHide();
        break;
      case BetterPlayerEventType.bufferingStart:
        setState(() => _isBuffering = true);
        _startBufferingTimeout();
        break;
      case BetterPlayerEventType.bufferingUpdate:
        _startBufferingTimeout();
        break;
      case BetterPlayerEventType.bufferingEnd:
        _bufferingTimer?.cancel();
        setState(() => _isBuffering = false);
        break;
      case BetterPlayerEventType.exception:
        _handlePlaybackFailure(
          message:
              'The HLS stream failed during playback. The URL may have expired.',
        );
        break;
      default:
        break;
    }
  }

  void _startStartupTimeout() {
    _startupTimer?.cancel();
    _startupTimer = Timer(_startupTimeout, () {
      if (!mounted || !_isPreparing || _playbackError != null) return;
      _handlePlaybackFailure(
        message:
            'The stream took too long to start. The playlist may be expired or blocked.',
      );
    });
  }

  void _startBufferingTimeout() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(_bufferingTimeout, () {
      if (!mounted || !_isBuffering || _playbackError != null) return;
      _handlePlaybackFailure(
        message:
            'Playback stalled while buffering. The HLS segments may have expired.',
      );
    });
  }

  Future<void> _handlePlaybackFailure({String? message}) async {
    if (!mounted) return;

    final request = _activeRequest;
    if (request != null && _retryCount < _maxRetriesPerProvider) {
      _retryCount += 1;
      _startupTimer?.cancel();
      _bufferingTimer?.cancel();
      _disposePlayer();
      setState(() {
        _activeUrl = null;
        _playbackError = null;
        _isPreparing = true;
        _isBuffering = false;
      });
      await Future<void>.delayed(Duration(milliseconds: 350 * _retryCount));
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
        _isBuffering = false;
      });
      return;
    }

    setState(() {
      _isPreparing = false;
      _isBuffering = false;
      _playbackError = message ??
          'Native playback could not start this HLS stream. Try another server or check the backend stream resolver.';
    });
  }

  void _retryCurrentProvider(StreamRequest request) {
    _startupTimer?.cancel();
    _bufferingTimer?.cancel();
    _disposePlayer();
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
        raw.toLowerCase().contains('connection') ||
        raw.toLowerCase().contains('took too long')) {
      return 'This server did not respond. Try another server.';
    }
    if (raw.toLowerCase().contains('expired') ||
        raw.toLowerCase().contains('403') ||
        raw.toLowerCase().contains('401')) {
      return 'This stream link expired or was rejected. Retry to request a fresh link, or pick another server.';
    }
    if (raw.toLowerCase().contains('m3u8') ||
        raw.toLowerCase().contains('hls') ||
        raw.toLowerCase().contains('extm3u')) {
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
                                      _isBuffering = false;
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
    final position = await _playerController?.videoPlayerController?.position;
    final duration = _playerController?.videoPlayerController?.value.duration;

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
