import '../bridge/turnstile_session.dart';
import '../controller/turnstile_controller.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_options.dart';
import '../core/turnstile_status.dart';
import '../engine/default_engine.dart';
import '../engine/turnstile_engine.dart';
import '../engine/turnstile_host_config.dart';
import '../html/turnstile_document_builder.dart';
import '../webview/turnstile_link_handler.dart';
import '../webview/turnstile_navigation_policy.dart';
import '../webview/turnstile_webview_config.dart';

/// Runs Turnstile off-screen, without any UI.
///
/// Meant for **invisible** site keys (or `appearance: interactionOnly` when
/// you accept failing over to a visible `TurnstileWidget`). If Cloudflare
/// requires an interaction, [getToken] throws a [TurnstileException] with
/// [TurnstileError.interactionRequired].
///
/// ```dart
/// final turnstile = TurnstileHeadless(
///   baseUrl: Uri.parse('https://your-domain.com'),
///   options: const TurnstileOptions(siteKey: '0x4AAAAAAA...'),
/// );
/// try {
///   final token = await turnstile.getToken();
/// } finally {
///   await turnstile.dispose();
/// }
/// ```
class TurnstileHeadless {
  /// Creates a headless runner. Nothing starts until [start] or [getToken].
  TurnstileHeadless({
    required TurnstileOptions options,
    required Uri baseUrl,
    TurnstileController? controller,
    TurnstileEngine? engine,
    TurnstileWebViewConfig webViewConfig = const TurnstileWebViewConfig(),
    TurnstileDocumentBuilder documentBuilder =
        const TurnstileHtmlDocumentBuilder(),
    TurnstileLinkHandler linkHandler = const IgnoreLinkHandler(),
    TurnstileNavigationPolicy? navigationPolicy,
  })  : config = TurnstileHostConfig(
          options: options,
          baseUrl: baseUrl,
          webViewConfig: webViewConfig,
          documentBuilder: documentBuilder,
          linkHandler: linkHandler,
          navigationPolicy: navigationPolicy,
        ),
        _engine = engine ?? createDefaultTurnstileEngine(),
        _controller = controller ?? TurnstileController(),
        _ownsController = controller == null;

  /// Hosting configuration.
  final TurnstileHostConfig config;

  final TurnstileEngine _engine;
  final TurnstileController _controller;
  final bool _ownsController;
  TurnstileHeadlessHost? _host;
  TurnstileSession? _session;
  Future<void>? _starting;
  bool _disposed = false;

  /// Controller driving the headless host (events, reset, ...).
  TurnstileController get controller => _controller;

  /// Whether the off-screen host has been started and not disposed.
  bool get isRunning => _host != null && !_disposed;

  /// Starts the off-screen host. Safe to call several times.
  Future<void> start() {
    if (_disposed) {
      return Future<void>.error(
        const TurnstileException(TurnstileError.disposed()),
      );
    }
    return _starting ??= _start();
  }

  Future<void> _start() async {
    final host = await _engine.startHeadless(
      config: config,
      onSessionCreated: (session) {
        _session = session;
        if (!_controller.isDisposed) _controller.attach(session);
      },
    );
    if (_disposed) {
      await host.dispose();
      return;
    }
    _host = host;
  }

  /// Starts if needed and returns a fresh, single-use token.
  ///
  /// When a token was already issued (or the last attempt failed), the widget
  /// is reset first so that each call yields a new token.
  Future<String> getToken({
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await start();
    const stale = {
      TurnstileStatus.verified,
      TurnstileStatus.failed,
      TurnstileStatus.expired,
      TurnstileStatus.timedOut,
    };
    if (_controller.isAttached && stale.contains(_controller.status)) {
      await _controller.reset();
    }
    return _controller.waitForToken(timeout: timeout, failOnInteraction: true);
  }

  /// Stops and frees the off-screen host. The instance cannot be reused.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final session = _session;
    _session = null;
    if (session != null) _controller.detach(session);
    final host = _host;
    _host = null;
    await host?.dispose();
    if (_ownsController) _controller.dispose();
  }
}
