import 'dart:collection';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../models/embed_source.dart';
import '../../models/media_details.dart';
import '../../providers/catalog_providers.dart';
import '../../services/local_library_repository.dart';

const _popupMitigationScript = r'''
(function () {
  if (window.__ocampoEmbedGuardsInstalled) return;
  window.__ocampoEmbedGuardsInstalled = true;

  var blockedSchemes = /^(intent|market|tel|mailto|sms|geo|whatsapp|tg|viber):/i;
  var blockedHosts = [
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adnxs.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'onclickads.net',
    'exoclick.com',
    'adsterra.com',
    'hilltopads.net'
  ];

  function hostBlocked(url) {
    try {
      var host = new URL(url, location.href).hostname.toLowerCase();
      return blockedHosts.some(function (blocked) {
        return host === blocked || host.endsWith('.' + blocked);
      });
    } catch (_) {
      return true;
    }
  }

  function shouldBlock(url) {
    if (!url) return true;
    if (blockedSchemes.test(String(url))) return true;
    if (hostBlocked(url)) return true;
    return /\/ads?\/|\/adserver\/|\/advert|\/banner|\/pop(?:up|under)|adtag|vpaid|vast\?/i.test(String(url));
  }

  window.open = function () { return null; };

  document.addEventListener('click', function (event) {
    var link = event.target && event.target.closest ? event.target.closest('a[href]') : null;
    if (!link) return;

    var href = link.getAttribute('href') || '';
    if (link.target && link.target !== '_self') {
      event.preventDefault();
      event.stopImmediatePropagation();
      return;
    }
    if (shouldBlock(href)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }, true);

  document.addEventListener('submit', function (event) {
    var action = event.target && event.target.action;
    if (action && shouldBlock(action)) {
      event.preventDefault();
      event.stopImmediatePropagation();
    }
  }, true);

  function hardenLinks(root) {
    (root || document).querySelectorAll('a[target], form[target]').forEach(function (node) {
      node.removeAttribute('target');
    });
  }

  hardenLinks(document);
  new MutationObserver(function (mutations) {
    mutations.forEach(function (mutation) {
      mutation.addedNodes.forEach(function (node) {
        if (node.nodeType === 1) hardenLinks(node);
      });
    });
  }).observe(document.documentElement, { childList: true, subtree: true });
})();
''';

const _pageCleanupScript = r'''
(function () {
  var selectors = [
    '[id*="ad" i]',
    '[class*="ad-" i]',
    '[class*="ads" i]',
    '[class*="advert" i]',
    '[class*="banner" i]',
    '[class*="popup" i]',
    '[class*="popunder" i]',
    '[class*="overlay" i]',
    'iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]',
    'iframe[src*="popads"]'
  ];

  selectors.forEach(function (selector) {
    try {
      document.querySelectorAll(selector).forEach(function (node) {
        var rect = node.getBoundingClientRect();
        var coversScreen = rect.width >= window.innerWidth * 0.55 && rect.height >= window.innerHeight * 0.30;
        if (coversScreen || selector.indexOf('iframe') === 0 || /ad|banner|popup|popunder/i.test(node.className + ' ' + node.id)) {
          node.style.setProperty('display', 'none', 'important');
          node.style.setProperty('pointer-events', 'none', 'important');
        }
      });
    } catch (_) {}
  });

  var closeLabels = /^(x|×|close|skip|dismiss|no thanks|not now)$/i;
  document.querySelectorAll('button, [role="button"], .close, .btn-close, [aria-label]').forEach(function (node) {
    var label = (node.getAttribute('aria-label') || node.textContent || '').trim();
    if (!closeLabels.test(label)) return;
    var rect = node.getBoundingClientRect();
    if (rect.width <= 120 && rect.height <= 80) {
      try { node.click(); } catch (_) {}
    }
  });
})();
''';

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
  final FocusNode _focusNode = FocusNode(debugLabel: 'PlaybackWebView');

  InAppWebViewController? _webViewController;
  EmbedRequest? _activeRequest;
  Uri? _activeEmbedUri;
  String? _selectedProvider;
  String? _playbackError;
  bool _isResolving = true;
  bool _isPageLoading = true;
  bool _controlsVisible = true;
  bool _webViewReady = false;
  int _retryCount = 0;
  double _progress = 0;
  Timer? _controlsTimer;
  Timer? _startupTimer;

  static const _maxRetriesPerProvider = 2;
  static const _startupTimeout = Duration(seconds: 28);
  static const _blockedHostSuffixes = <String>[
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adnxs.com',
    'adsystem.com',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'propeller-tracking.com',
    'onclickads.net',
    'exoclick.com',
    'juicyads.com',
    'trafficjunky.net',
    'revcontent.com',
    'taboola.com',
    'outbrain.com',
    'mgid.com',
    'adsterra.com',
    'hilltopads.net',
    'pushnative.com',
    'yllix.com',
    'histats.com',
    'scorecardresearch.com',
  ];
  static const _blockedUrlFragments = <String>[
    '/ads/',
    '/adserver/',
    '/advert',
    '/banner',
    '/popunder',
    '/popup',
    'ad_click',
    'adtag',
    'clickadu',
    'vast?',
    'vpaid',
  ];

  @override
  void initState() {
    super.initState();
    _enterPlayerMode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _startupTimer?.cancel();
    _focusNode.dispose();
    _exitPlayerMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(embedProvidersProvider);
    final providerOptions =
        providers.valueOrNull ?? const <EmbedProviderInfo>[];
    final configuredProviders = providerOptions
        .where((provider) => provider.configured && provider.enabled)
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
        body: _PlaybackError(
          message: providers.hasError
              ? 'The embed server list could not be loaded. Check the backend URL and environment variables.'
              : 'No configured embed providers were found. Add provider URLs in the backend environment, then redeploy.',
          onRetry: () => ref.invalidate(embedProvidersProvider),
        ),
      );
    }

    final request = EmbedRequest(
      mediaType: widget.mediaType,
      id: widget.id,
      season: widget.season,
      episode: widget.episode,
      provider: selectedProvider?.id,
    );
    final source = ref.watch(embedSourceProvider(request));

    return PopScope(
      canPop: true,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.goBack): DismissIntent(),
          SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
          SingleActivator(LogicalKeyboardKey.contextMenu):
              _ShowControlsIntent(),
          SingleActivator(LogicalKeyboardKey.mediaPlayPause):
              _ShowControlsIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _showControlsTemporarily();
                return null;
              },
            ),
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                Navigator.of(context).maybePop();
                return null;
              },
            ),
            _ShowControlsIntent: CallbackAction<_ShowControlsIntent>(
              onInvoke: (_) {
                _showControlsTemporarily();
                return null;
              },
            ),
          },
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: source.when(
                data: (source) => _buildPlayer(
                  context,
                  source,
                  request,
                  providerOptions,
                  effectiveProvider.id,
                  providers.isLoading,
                ),
                error: (error, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    _PlaybackError(
                      message: _friendlyPlaybackMessage(error),
                      onRetry: () => _retryCurrentProvider(request),
                    ),
                    _bottomServerSwitcher(
                      providerOptions,
                      effectiveProvider.id,
                      providers.isLoading,
                      request: request,
                    ),
                  ],
                ),
                loading: () => const _LoadingOverlay(
                  message: 'Preparing embed...',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayer(
    BuildContext context,
    EmbedSource source,
    EmbedRequest request,
    List<EmbedProviderInfo> providers,
    String selectedProvider,
    bool providersLoading,
  ) {
    final embedUri = Uri.parse(source.embedUrl);
    _prepareEmbed(source, request, embedUri);

    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _showControlsTemporarily(),
          child: InAppWebView(
            key: ValueKey(source.embedUrl),
            initialUrlRequest: URLRequest(url: WebUri(source.embedUrl)),
            initialUserScripts: _initialUserScripts(),
            initialSettings: _webViewSettings(),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _webViewReady = true;
            },
            onLoadStart: (_, url) {
              if (!_isMainEmbedUrl(url, embedUri)) return;
              if (!mounted) return;
              setState(() {
                _isPageLoading = true;
                _playbackError = null;
                _progress = 0;
              });
              _startStartupTimeout(request);
            },
            onProgressChanged: (_, progress) {
              if (!mounted) return;
              setState(() => _progress = progress / 100);
            },
            onLoadStop: (_, url) {
              if (!_isMainEmbedUrl(url, embedUri)) return;
              _startupTimer?.cancel();
              _injectMitigationScripts();
              if (!mounted) return;
              setState(() {
                _isResolving = false;
                _isPageLoading = false;
                _playbackError = null;
                _progress = 1;
              });
              _scheduleControlsHide();
            },
            onReceivedError: (_, request, error) {
              if (request.isForMainFrame != true) return;
              _handlePlaybackFailure(
                request: _activeRequest,
                message:
                    'The embed page failed to load. Retry or pick another server.',
              );
            },
            onReceivedHttpError: (_, request, response) {
              if (request.isForMainFrame != true) return;
              if ((response.statusCode ?? 0) < 400) return;
              _handlePlaybackFailure(
                request: _activeRequest,
                message:
                    'The embed gateway returned HTTP ${response.statusCode}. Retry or pick another server.',
              );
            },
            shouldOverrideUrlLoading: (_, navigationAction) async {
              final uri = navigationAction.request.url;
              final isMainFrame = navigationAction.isForMainFrame;
              if (uri == null) return NavigationActionPolicy.CANCEL;
              if (_shouldBlockUrl(uri)) {
                _showControlsTemporarily();
                return NavigationActionPolicy.CANCEL;
              }
              if (isMainFrame && !_isAllowedTopLevelNavigation(uri, embedUri)) {
                _showControlsTemporarily();
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.ALLOW;
            },
            shouldInterceptRequest: (_, request) async {
              final uri = request.url;
              if (_shouldBlockUrl(uri)) return _blockedResourceResponse();
              return null;
            },
            onCreateWindow: (_, createWindowAction) async {
              _showControlsTemporarily();
              return false;
            },
            onEnterFullscreen: (_) => _enterPlayerMode(),
            onExitFullscreen: (_) => _enterPlayerMode(),
          ),
        ),
        if (_isResolving || _isPageLoading)
          _LoadingOverlay(
            message: _isResolving ? 'Preparing embed...' : 'Loading player...',
            progress: _progress,
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
            providers,
            selectedProvider,
            providersLoading,
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
                    providerName: source.provider.isEmpty
                        ? selectedProvider
                        : source.provider,
                    canReload: _webViewReady,
                    onBack: () => Navigator.of(context).maybePop(),
                    onReload: _reloadWebView,
                    onServers: () => _showServerSheet(
                      context,
                      providers,
                      selectedProvider,
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
  }

  void _prepareEmbed(EmbedSource source, EmbedRequest request, Uri embedUri) {
    if (_activeEmbedUri?.toString() == source.embedUrl) return;

    _activeRequest = request.provider == null
        ? EmbedRequest(
            mediaType: request.mediaType,
            id: request.id,
            season: request.season,
            episode: request.episode,
            provider: source.provider,
          )
        : request;
    _activeEmbedUri = embedUri;
    _retryCount = 0;
    _isResolving = false;
    _isPageLoading = true;
    _playbackError = null;
    _progress = 0;
    _startStartupTimeout(request);
  }

  InAppWebViewSettings _webViewSettings() {
    return InAppWebViewSettings(
      javaScriptEnabled: true,
      javaScriptCanOpenWindowsAutomatically: false,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllowFullscreen: true,
      supportMultipleWindows: false,
      useShouldOverrideUrlLoading: true,
      useShouldInterceptRequest: true,
      transparentBackground: false,
      disableContextMenu: true,
      disableDefaultErrorPage: true,
      disableLongPressContextMenuOnLinks: true,
      supportZoom: false,
      builtInZoomControls: false,
      displayZoomControls: false,
      domStorageEnabled: true,
      databaseEnabled: true,
      thirdPartyCookiesEnabled: true,
      useWideViewPort: true,
      loadWithOverviewMode: true,
      mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
      contentBlockers: _contentBlockers(),
      regexToCancelSubFramesLoading:
          r'^(intent|market|tel|mailto|sms|geo|whatsapp|tg|viber):.*',
      userAgent:
          'Mozilla/5.0 (Linux; Android TV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    );
  }

  UnmodifiableListView<UserScript> _initialUserScripts() {
    return UnmodifiableListView<UserScript>([
      UserScript(
        groupName: 'embed-popup-mitigation',
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
        source: _popupMitigationScript,
      ),
    ]);
  }

  List<ContentBlocker> _contentBlockers() {
    final adHosts = _blockedHostSuffixes
        .map((host) => host.replaceAll('.', r'\.'))
        .join('|');

    return [
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: r'.*://([^/]+\.)?(' + adHosts + r')/.*',
          urlFilterIsCaseSensitive: false,
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter:
              r'.*(/ads?/|/adserver/|/advert|/banner|/popunder|/popup|adtag|vpaid|vast\?).*',
          urlFilterIsCaseSensitive: false,
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
  }

  Future<void> _injectMitigationScripts() async {
    await _webViewController?.evaluateJavascript(
        source: _popupMitigationScript);
    await _webViewController?.evaluateJavascript(source: _pageCleanupScript);
  }

  bool _isMainEmbedUrl(WebUri? url, Uri embedUri) {
    if (url == null) return false;
    final current = Uri.tryParse(url.toString());
    if (current == null) return false;
    return current.scheme == embedUri.scheme &&
        current.host == embedUri.host &&
        current.path == embedUri.path;
  }

  bool _isAllowedTopLevelNavigation(WebUri uri, Uri embedUri) {
    final current = Uri.tryParse(uri.toString());
    if (current == null) return false;
    if (current.scheme != 'https') return false;
    return current.host == embedUri.host && current.path == embedUri.path;
  }

  bool _shouldBlockUrl(WebUri uri) {
    final parsed = Uri.tryParse(uri.toString());
    if (parsed == null) return true;

    final scheme = parsed.scheme.toLowerCase();
    if (scheme.isEmpty) return false;
    if (scheme != 'https' && scheme != 'http') return true;
    if (scheme == 'http') return true;

    final host = parsed.host.toLowerCase();
    if (host.isEmpty) return true;
    if (_blockedHostSuffixes.any(
      (suffix) => host == suffix || host.endsWith('.$suffix'),
    )) {
      return true;
    }

    final url = parsed.toString().toLowerCase();
    return _blockedUrlFragments.any(url.contains);
  }

  WebResourceResponse _blockedResourceResponse() {
    return WebResourceResponse(
      contentType: 'text/plain',
      contentEncoding: 'utf-8',
      data: Uint8List(0),
      statusCode: 204,
      reasonPhrase: 'No Content',
      headers: const <String, String>{
        'Cache-Control': 'no-store',
      },
    );
  }

  void _startStartupTimeout(EmbedRequest? request) {
    _startupTimer?.cancel();
    _startupTimer = Timer(_startupTimeout, () {
      if (!mounted || _playbackError != null) return;
      if (!_isResolving && !_isPageLoading) return;
      _handlePlaybackFailure(
        request: request,
        message:
            'The embed page took too long to load. Retry or pick another server.',
      );
    });
  }

  Future<void> _handlePlaybackFailure({
    required EmbedRequest? request,
    String? message,
  }) async {
    if (!mounted) return;

    if (request != null && _retryCount < _maxRetriesPerProvider) {
      _retryCount += 1;
      _startupTimer?.cancel();
      setState(() {
        _activeEmbedUri = null;
        _playbackError = null;
        _isResolving = true;
        _isPageLoading = true;
        _progress = 0;
      });
      await Future<void>.delayed(Duration(milliseconds: 350 * _retryCount));
      ref.invalidate(embedSourceProvider(request));
      return;
    }

    final providers = ref.read(embedProvidersProvider).valueOrNull ??
        const <EmbedProviderInfo>[];
    final configuredProviders = providers
        .where((provider) => provider.configured && provider.enabled)
        .toList(growable: false);
    final nextProvider = _nextProvider(configuredProviders);

    if (nextProvider != null) {
      setState(() {
        _selectedProvider = nextProvider.id;
        _activeEmbedUri = null;
        _playbackError = null;
        _isResolving = true;
        _isPageLoading = true;
        _progress = 0;
      });
      return;
    }

    setState(() {
      _isResolving = false;
      _isPageLoading = false;
      _playbackError = message ??
          'The embed player could not start. Try another server or request a fresh link.';
    });
  }

  void _retryCurrentProvider(EmbedRequest request) {
    _startupTimer?.cancel();
    setState(() {
      _activeEmbedUri = null;
      _playbackError = null;
      _isResolving = true;
      _isPageLoading = true;
      _progress = 0;
    });
    ref.invalidate(embedSourceProvider(request));
  }

  Future<void> _reloadWebView() async {
    _showControlsTemporarily();
    setState(() {
      _playbackError = null;
      _isPageLoading = true;
      _progress = 0;
    });
    await _webViewController?.reload();
  }

  Widget _bottomServerSwitcher(
    List<EmbedProviderInfo> providers,
    String selectedProvider,
    bool isLoading, {
    EmbedRequest? request,
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
                _activeEmbedUri = null;
                _playbackError = null;
                _isResolving = true;
                _isPageLoading = true;
              });
              if (request != null) {
                ref.invalidate(embedSourceProvider(request));
              }
            },
          ),
        ),
      ),
    );
  }

  void _showControlsTemporarily() {
    if (!_controlsVisible && mounted) {
      setState(() => _controlsVisible = true);
    }
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted ||
          _isResolving ||
          _isPageLoading ||
          _playbackError != null) {
        return;
      }
      setState(() => _controlsVisible = false);
    });
  }

  String _friendlyPlaybackMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('501') || raw.contains('disabled or unsupported')) {
      return 'This embed provider is not configured. Pick another server or update the backend environment variables.';
    }
    if (raw.contains('token') || raw.contains('401') || raw.contains('403')) {
      return 'The signed embed link expired or was rejected. Retry to request a fresh link.';
    }
    if (raw.contains('socket') ||
        raw.contains('timeout') ||
        raw.contains('connection') ||
        raw.contains('too long')) {
      return 'This embed provider did not respond. Try another server.';
    }
    if (raw.contains('https') || raw.contains('invalid embed')) {
      return 'The backend returned an invalid embed URL. Check the Worker gateway configuration.';
    }
    return 'This embed provider could not start playback. Try another server.';
  }

  EmbedProviderInfo? _providerById(
    List<EmbedProviderInfo> providers,
    String id,
  ) {
    for (final provider in providers) {
      if (provider.id == id) return provider;
    }
    return null;
  }

  EmbedProviderInfo? _defaultPlaybackProvider(
    List<EmbedProviderInfo> providers,
  ) {
    return providers.isEmpty ? null : providers.first;
  }

  EmbedProviderInfo? _nextProvider(List<EmbedProviderInfo> providers) {
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
    List<EmbedProviderInfo> providers,
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
                            onSelected: provider.configured && provider.enabled
                                ? (_) {
                                    Navigator.of(context).pop();
                                    if (provider.id == selectedProvider) {
                                      return;
                                    }
                                    setState(() {
                                      _selectedProvider = provider.id;
                                      _activeEmbedUri = null;
                                      _playbackError = null;
                                      _isResolving = true;
                                      _isPageLoading = true;
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
    await ref.read(libraryControllerProvider.notifier).saveProgress(
          _detailsShell(),
          positionSeconds: 0,
          durationSeconds: 0,
          season: widget.season,
          episode: widget.episode,
        );
    _showControlsTemporarily();
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

  void _enterPlayerMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  void _exitPlayerMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

class _ShowControlsIntent extends Intent {
  const _ShowControlsIntent();
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({
    required this.message,
    this.progress = 0,
  });

  final String message;
  final double progress;

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
            if (progress > 0 && progress < 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: 220,
                child: LinearProgressIndicator(
                  value: progress.clamp(0, 1),
                  minHeight: 3,
                  color: AppColors.netflixRed,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ],
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

  final List<EmbedProviderInfo> providers;
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
                        color: provider.configured && provider.enabled
                            ? Colors.white
                            : AppColors.textMuted,
                        fontWeight: FontWeight.w800,
                      ),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  onSelected: provider.configured && provider.enabled
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
    required this.providerName,
    required this.canReload,
    required this.onBack,
    required this.onReload,
    required this.onServers,
    required this.onSaveProgress,
    this.onNextEpisode,
  });

  final String mediaType;
  final String providerName;
  final bool canReload;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onServers;
  final VoidCallback onSaveProgress;
  final VoidCallback? onNextEpisode;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton.filledTonal(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          FilledButton.icon(
            onPressed: onServers,
            icon: const Icon(Icons.dns_rounded),
            label: Text(providerName.isEmpty ? 'Servers' : providerName),
            style: _buttonStyle(context),
          ),
          FilledButton.icon(
            onPressed: canReload ? onReload : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reload'),
            style: _buttonStyle(context),
          ),
          FilledButton.icon(
            onPressed: onSaveProgress,
            icon: const Icon(Icons.bookmark_rounded),
            label: const Text('Save'),
            style: _buttonStyle(context),
          ),
          if (mediaType == 'tv' && onNextEpisode != null)
            FilledButton.icon(
              onPressed: onNextEpisode,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Next'),
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
      disabledBackgroundColor: Colors.black.withValues(alpha: 0.34),
      disabledForegroundColor: Colors.white38,
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
