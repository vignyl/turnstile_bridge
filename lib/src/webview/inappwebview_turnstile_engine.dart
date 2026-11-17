import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../bridge/turnstile_session.dart';
import '../engine/turnstile_engine.dart';
import '../engine/turnstile_host_config.dart';
import 'turnstile_webview_delegate.dart';

/// [TurnstileEngine] backed by `flutter_inappwebview`.
///
/// Supports Android, iOS, macOS, Windows (WebView2) and Linux (WPE WebKit).
class InAppWebViewTurnstileEngine implements TurnstileEngine {
  /// Creates the engine.
  const InAppWebViewTurnstileEngine();

  @override
  Widget buildView({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    return _InAppWebViewTurnstileHost(
      config: config,
      onSessionCreated: onSessionCreated,
      gestureRecognizers: gestureRecognizers,
    );
  }

  @override
  Future<TurnstileHeadlessHost> startHeadless({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
  }) async {
    final delegate = _createDelegate(config, onSessionCreated);
    final webView = HeadlessInAppWebView(
      initialData: delegate.document,
      initialSettings: config.webViewConfig.toSettings(),
      initialSize: config.options.size.preferredSize,
      onWebViewCreated: delegate.onWebViewCreated,
      shouldOverrideUrlLoading: delegate.shouldOverrideUrlLoading,
      onCreateWindow: delegate.onCreateWindow,
      onReceivedError: delegate.onReceivedError,
    );
    await webView.run();
    return _InAppWebViewHeadlessHost(webView, delegate);
  }
}

TurnstileWebViewDelegate _createDelegate(
  TurnstileHostConfig config,
  TurnstileSessionCallback onSessionCreated,
) {
  return TurnstileWebViewDelegate(
    document: createTurnstileDocument(
      options: config.options,
      baseUrl: config.baseUrl,
      builder: config.documentBuilder,
    ),
    navigationPolicy: config.navigationPolicy,
    linkHandler: config.linkHandler,
    onSessionCreated: onSessionCreated,
  );
}

class _InAppWebViewHeadlessHost implements TurnstileHeadlessHost {
  _InAppWebViewHeadlessHost(this._webView, this._delegate);

  final HeadlessInAppWebView _webView;
  final TurnstileWebViewDelegate _delegate;
  bool _disposed = false;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _delegate.session?.close();
    await _webView.dispose();
  }
}

/// Owns one `InAppWebView` and its session for its whole lifetime.
class _InAppWebViewTurnstileHost extends StatefulWidget {
  const _InAppWebViewTurnstileHost({
    required this.config,
    required this.onSessionCreated,
    this.gestureRecognizers,
  });

  final TurnstileHostConfig config;
  final TurnstileSessionCallback onSessionCreated;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  @override
  State<_InAppWebViewTurnstileHost> createState() =>
      _InAppWebViewTurnstileHostState();
}

class _InAppWebViewTurnstileHostState
    extends State<_InAppWebViewTurnstileHost> {
  late final TurnstileWebViewDelegate _delegate =
      _createDelegate(widget.config, _onSessionCreated);
  late final InAppWebViewSettings _settings =
      widget.config.webViewConfig.toSettings();

  void _onSessionCreated(TurnstileSession session) {
    if (mounted) widget.onSessionCreated(session);
  }

  @override
  void dispose() {
    unawaited(_delegate.session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: _delegate.document,
      initialSettings: _settings,
      gestureRecognizers: widget.gestureRecognizers,
      onWebViewCreated: _delegate.onWebViewCreated,
      shouldOverrideUrlLoading: _delegate.shouldOverrideUrlLoading,
      onCreateWindow: _delegate.onCreateWindow,
      onReceivedError: _delegate.onReceivedError,
    );
  }
}
