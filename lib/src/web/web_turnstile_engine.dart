import 'dart:async';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../engine/turnstile_engine.dart';
import '../engine/turnstile_host_config.dart';
import '../html/turnstile_document_builder.dart';
import 'web_turnstile_session.dart';

/// [TurnstileEngine] for Flutter web: renders Turnstile in the page itself,
/// without any iframe of ours, so Cloudflare validates the site's real domain.
class WebTurnstileEngine implements TurnstileEngine {
  /// Creates the engine.
  const WebTurnstileEngine();

  /// Script URL from a [TurnstileHtmlDocumentBuilder], or the official one.
  static String _scriptUrl(TurnstileHostConfig config) {
    final builder = config.documentBuilder;
    return builder is TurnstileHtmlDocumentBuilder
        ? builder.scriptUrl
        : TurnstileHtmlDocumentBuilder.defaultScriptUrl;
  }

  @override
  Widget buildView({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    return _WebTurnstileHost(
      config: config,
      scriptUrl: _scriptUrl(config),
      onSessionCreated: onSessionCreated,
    );
  }

  @override
  Future<TurnstileHeadlessHost> startHeadless({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
  }) async {
    config.options.ensureValid();
    final size = config.options.size.preferredSize;
    final host = web.HTMLDivElement();
    host.style
      ..position = 'fixed'
      ..left = '-10000px'
      ..top = '0'
      ..width = '${size.width}px'
      ..height = '${size.height}px'
      ..overflow = 'hidden';
    host.setAttribute('aria-hidden', 'true');
    web.document.body!.append(host);

    final session = WebTurnstileSession(
      options: config.options,
      host: host,
      scriptUrl: _scriptUrl(config),
    );
    onSessionCreated(session);
    unawaited(session.start());
    return _WebHeadlessHost(host, session);
  }
}

class _WebHeadlessHost implements TurnstileHeadlessHost {
  _WebHeadlessHost(this._host, this._session);

  final web.HTMLElement _host;
  final WebTurnstileSession _session;
  bool _disposed = false;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _session.close();
    _host.remove();
  }
}

/// Owns one platform view element and its session.
class _WebTurnstileHost extends StatefulWidget {
  const _WebTurnstileHost({
    required this.config,
    required this.scriptUrl,
    required this.onSessionCreated,
  });

  final TurnstileHostConfig config;
  final String scriptUrl;
  final TurnstileSessionCallback onSessionCreated;

  @override
  State<_WebTurnstileHost> createState() => _WebTurnstileHostState();
}

class _WebTurnstileHostState extends State<_WebTurnstileHost> {
  static int _nextViewId = 0;

  late final String _viewType = 'turnstile-bridge-view-${_nextViewId++}';
  late final web.HTMLDivElement _host = _createHostElement();
  WebTurnstileSession? _session;

  web.HTMLDivElement _createHostElement() {
    final element = web.HTMLDivElement();
    element.style
      ..width = '100%'
      ..height = '100%'
      ..overflow = 'hidden';
    return element;
  }

  @override
  void initState() {
    super.initState();
    widget.config.options.ensureValid();
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _host,
    );
  }

  void _onPlatformViewCreated(int _) {
    if (!mounted || _session != null) return;
    final session = WebTurnstileSession(
      options: widget.config.options,
      host: _host,
      scriptUrl: widget.scriptUrl,
    );
    _session = session;
    widget.onSessionCreated(session);
    unawaited(session.start());
  }

  @override
  void dispose() {
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(
      viewType: _viewType,
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
