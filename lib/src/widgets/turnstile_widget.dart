import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../bridge/turnstile_session.dart';
import '../controller/turnstile_controller.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';
import '../core/turnstile_options.dart';
import '../core/turnstile_status.dart';
import '../engine/default_engine.dart';
import '../engine/turnstile_engine.dart';
import '../engine/turnstile_host_config.dart';
import '../html/turnstile_document_builder.dart';
import '../webview/turnstile_link_handler.dart';
import '../webview/turnstile_navigation_policy.dart';
import '../webview/turnstile_webview_config.dart';

/// Called with a fresh Turnstile token.
typedef TurnstileTokenCallback = void Function(String token);

/// Called when Turnstile or the bridge fails.
typedef TurnstileErrorCallback = void Function(TurnstileError error);

/// Called for every Turnstile event.
typedef TurnstileEventCallback = void Function(TurnstileEvent event);

/// Displays a Cloudflare Turnstile widget.
///
/// ```dart
/// TurnstileWidget(
///   baseUrl: Uri.parse('https://your-domain.com'),
///   options: const TurnstileOptions(siteKey: '0x4AAAAAAA...'),
///   onTokenReceived: (token) => api.login(captchaToken: token),
/// )
/// ```
///
/// On Android, iOS, macOS, Windows and Linux the widget runs in a WebView
/// whose page is served from [baseUrl]: its host must be allowed for the site
/// key in the Cloudflare dashboard. On the web, Turnstile renders directly in
/// your page and Cloudflare checks your site's own domain; [baseUrl] is then
/// ignored.
///
/// The host is created when the widget is inserted and freed when it is
/// removed from the tree. Use a [TurnstileController] to reset or destroy it
/// earlier.
class TurnstileWidget extends StatefulWidget {
  /// Creates a Turnstile widget.
  const TurnstileWidget({
    super.key,
    required this.options,
    required this.baseUrl,
    this.controller,
    this.engine,
    this.webViewConfig = const TurnstileWebViewConfig(),
    this.documentBuilder = const TurnstileHtmlDocumentBuilder(),
    this.linkHandler = const SystemBrowserLinkHandler(),
    this.navigationPolicy,
    this.onTokenReceived,
    this.onError,
    this.onExpired,
    this.onEvent,
    this.resizeDuration = const Duration(milliseconds: 200),
    this.gestureRecognizers,
  });

  /// Turnstile configuration (site key, theme, size, ...).
  final TurnstileOptions options;

  /// Origin of the WebView page; its host must be allowed for the site key.
  /// Ignored on the web.
  final Uri baseUrl;

  /// Optional controller. When `null`, the widget creates and disposes one.
  final TurnstileController? controller;

  /// Hosting engine. Defaults to the engine of the current platform.
  final TurnstileEngine? engine;

  /// WebView settings.
  final TurnstileWebViewConfig webViewConfig;

  /// Generates the hosting HTML page (and gives the script URL on the web).
  final TurnstileDocumentBuilder documentBuilder;

  /// Opens links leaving the widget (privacy policy, terms).
  final TurnstileLinkHandler linkHandler;

  /// Navigation rules. Defaults to [DefaultTurnstileNavigationPolicy].
  final TurnstileNavigationPolicy? navigationPolicy;

  /// Called with each new token.
  final TurnstileTokenCallback? onTokenReceived;

  /// Called on each error.
  final TurnstileErrorCallback? onError;

  /// Called when the token expires.
  final VoidCallback? onExpired;

  /// Called for every event, including the ones above.
  final TurnstileEventCallback? onEvent;

  /// Duration of the size animation when Turnstile resizes.
  final Duration resizeDuration;

  /// Gestures the WebView should claim (useful inside scrollables).
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  @override
  State<TurnstileWidget> createState() => _TurnstileWidgetState();
}

class _TurnstileWidgetState extends State<TurnstileWidget> {
  /// A zero-height platform view may be throttled; keep 1 logical pixel.
  static const double _minHeight = 1;

  TurnstileController? _ownedController;
  late TurnstileController _controller;
  StreamSubscription<TurnstileEvent>? _subscription;
  late TurnstileEngine _engine;
  late TurnstileHostConfig _config;
  TurnstileSession? _session;
  bool _destroyed = false;
  int _generation = 0;
  Size? _contentSize;

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? createDefaultTurnstileEngine();
    _config = _createConfig();
    _bindController(
      widget.controller ?? (_ownedController = TurnstileController()),
    );
  }

  @override
  void didUpdateWidget(TurnstileWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      _unbindController();
      final previouslyOwned = _ownedController;
      _ownedController = null;
      final next =
          widget.controller ?? (_ownedController = TurnstileController());
      _bindController(next);
      final session = _session;
      if (session != null) next.attach(session);
      previouslyOwned?.dispose();
    }

    final engineChanged = widget.engine != oldWidget.engine;
    if (engineChanged) {
      _engine = widget.engine ?? createDefaultTurnstileEngine();
    }
    final config = _createConfig();
    if (engineChanged || config != _config) {
      _config = config;
      _recreateHost();
    }
  }

  @override
  void dispose() {
    // The host widget closes its own session when it is disposed.
    _unbindController();
    _session = null;
    _ownedController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------

  TurnstileHostConfig _createConfig() => TurnstileHostConfig(
        options: widget.options,
        baseUrl: widget.baseUrl,
        webViewConfig: widget.webViewConfig,
        documentBuilder: widget.documentBuilder,
        linkHandler: widget.linkHandler,
        navigationPolicy: widget.navigationPolicy,
      );

  /// Drops the current host; a new one is built with a new key.
  void _recreateHost() {
    final session = _session;
    _session = null;
    if (session != null) _controller.detach(session);
    _generation++;
    _contentSize = null;
  }

  void _onSessionCreated(TurnstileSession session) {
    if (!mounted) return;
    final previous = _session;
    if (previous != null) _controller.detach(previous);
    _session = session;
    if (!_controller.isDisposed) _controller.attach(session);
  }

  void _bindController(TurnstileController controller) {
    _controller = controller;
    _destroyed = controller.status == TurnstileStatus.destroyed;
    controller.addListener(_onControllerChanged);
    _subscription = controller.events.listen(_onEvent);
  }

  void _unbindController() {
    _controller.removeListener(_onControllerChanged);
    unawaited(_subscription?.cancel());
    _subscription = null;
    final session = _session;
    if (session != null) _controller.detach(session);
  }

  void _onControllerChanged() {
    final destroyed = _controller.status == TurnstileStatus.destroyed;
    if (destroyed == _destroyed || !mounted) return;
    setState(() {
      _destroyed = destroyed;
      if (destroyed) {
        // controller.destroy() already closed the session.
        _session = null;
        _contentSize = null;
      } else {
        _recreateHost();
      }
    });
  }

  void _onEvent(TurnstileEvent event) {
    if (!mounted) return;
    widget.onEvent?.call(event);
    switch (event) {
      case TurnstileTokenReceived(:final token):
        widget.onTokenReceived?.call(token);
      case TurnstileFailed(:final error):
        widget.onError?.call(error);
      case TurnstileExpired():
        widget.onExpired?.call();
      case TurnstileResized(:final size):
        if (size != _contentSize) setState(() => _contentSize = size);
      default:
        break;
    }
  }

  Size _targetSize() {
    final preferred = widget.options.size.preferredSize;
    final reported = _contentSize;
    final hiddenUntilNeeded =
        widget.options.appearance != TurnstileAppearance.always;
    final height =
        reported?.height ?? (hiddenUntilNeeded ? 0 : preferred.height);
    final width = reported == null || reported.width < preferred.width
        ? preferred.width
        : reported.width;
    return Size(width, math.max(height, _minHeight));
  }

  @override
  Widget build(BuildContext context) {
    if (_destroyed) return const SizedBox.shrink();
    final size = _targetSize();
    final flexible = widget.options.size == TurnstileSize.flexible;

    final sized = SizedBox(
      width: flexible ? double.infinity : size.width,
      height: size.height,
      child: KeyedSubtree(
        key: ValueKey<int>(_generation),
        child: _engine.buildView(
          config: _config,
          onSessionCreated: _onSessionCreated,
          gestureRecognizers: widget.gestureRecognizers,
        ),
      ),
    );
    // AnimatedSize asserts when given a zero duration.
    if (widget.resizeDuration == Duration.zero) return sized;
    return AnimatedSize(
      duration: widget.resizeDuration,
      alignment: Alignment.topCenter,
      child: sized,
    );
  }
}
