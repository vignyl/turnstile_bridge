import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../bridge/turnstile_command.dart';
import '../bridge/turnstile_message_decoder.dart';
import '../bridge/turnstile_session.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';
import '../core/turnstile_options.dart';
import 'js_turnstile.dart';

/// [TurnstileSession] rendering Turnstile directly in the current web page.
///
/// Messages are produced in the same `{"type": ...}` shape as the WebView
/// page and go through the same [TurnstileMessageDecoder], so both engines
/// share one event contract.
class WebTurnstileSession implements TurnstileSession {
  /// Creates a session rendering into a new element appended to [host].
  WebTurnstileSession({
    required this.options,
    required web.HTMLElement host,
    required this.scriptUrl,
    TurnstileMessageDecoder decoder = const JsonTurnstileMessageDecoder(),
  })  : _decoder = decoder,
        _container = web.HTMLDivElement() {
    _container.style.display =
        options.size == TurnstileSize.flexible ? 'block' : 'inline-block';
    host.append(_container);
  }

  /// Turnstile configuration.
  final TurnstileOptions options;

  /// URL of `api.js`.
  final String scriptUrl;

  final TurnstileMessageDecoder _decoder;
  final web.HTMLDivElement _container;
  final StreamController<TurnstileEvent> _events =
      StreamController<TurnstileEvent>.broadcast();
  web.ResizeObserver? _resizeObserver;
  JSAny? _widgetId;
  (int, int)? _lastSize;
  bool _rendered = false;
  bool _closed = false;

  static const Duration _attachPollInterval = Duration(milliseconds: 50);

  @override
  Stream<TurnstileEvent> get events => _events.stream;

  /// Waits for the element to be in the DOM, loads `api.js` and renders.
  Future<void> start() async {
    _observeSize();
    try {
      await _waitUntilConnected();
      await TurnstileScriptLoader.ensureLoaded(scriptUrl);
    } on TurnstileException catch (exception) {
      _emit(TurnstileFailed(exception.error));
      return;
    }
    if (!_closed) _render();
  }

  @override
  Future<Object?> run(TurnstileCommand command) async {
    if (_closed) throw const TurnstileException(TurnstileError.disposed());
    try {
      return _execute(command);
    } on TurnstileException {
      rethrow;
    } catch (error) {
      throw TurnstileException(TurnstileError.javascriptFailed('$error'));
    }
  }

  Object? _execute(TurnstileCommand command) {
    final api = jsTurnstile;
    final widgetId = _widgetId;
    switch (command) {
      case TurnstileCommand.render:
        return _render()?.dartify();
      case TurnstileCommand.reset:
        if (api != null && widgetId != null) {
          api.reset(widgetId);
          return true;
        }
        return _render() != null;
      case TurnstileCommand.remove:
        if (api != null && widgetId != null) api.remove(widgetId);
        _widgetId = null;
        _reportSize();
        return true;
      case TurnstileCommand.execute:
        if (api == null) return false;
        if (_widgetId == null) _render();
        if (_widgetId == null) return false;
        api.execute(_container);
        return true;
      case TurnstileCommand.getResponse:
        if (api == null || widgetId == null) return null;
        return api.getResponse(widgetId)?.dartify();
      case TurnstileCommand.isExpired:
        if (api == null || widgetId == null) return false;
        return api.isExpired(widgetId)?.dartify() == true;
    }
  }

  @override
  Future<void> reload() async {
    if (_closed) throw const TurnstileException(TurnstileError.disposed());
    await run(TurnstileCommand.remove);
    if (jsTurnstile == null) {
      await start();
    } else {
      _render();
    }
  }

  @override
  Future<void> destroy() async {
    if (_closed) return;
    try {
      await run(TurnstileCommand.remove);
    } on Object {
      // Closing is what matters.
    }
    await close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _resizeObserver?.disconnect();
    _resizeObserver = null;
    final api = jsTurnstile;
    final widgetId = _widgetId;
    _widgetId = null;
    if (api != null && widgetId != null) {
      try {
        api.remove(widgetId);
      } on Object {
        // Already gone.
      }
    }
    _container.remove();
    await _events.close();
  }

  // ---------------------------------------------------------------------------

  JSAny? _render() {
    final api = jsTurnstile;
    if (api == null || _closed) return null;
    if (_widgetId != null) return _widgetId;

    final params = options.toRenderParameters().jsify()! as JSObject;
    void on(String name, JSFunction callback) =>
        params.setProperty(name.toJS, callback);

    on('callback', (JSAny? token) {
      _post({'type': 'token', 'token': token?.dartify()?.toString()});
    }.toJS);
    on('error-callback', (JSAny? code) {
      _post({'type': 'error', 'code': code?.dartify()?.toString()});
      return true.toJS;
    }.toJS);
    JSFunction notify(String type) => () {
          _post({'type': type});
        }.toJS;
    on('expired-callback', notify('expired'));
    on('timeout-callback', notify('timeout'));
    on('before-interactive-callback', notify('beforeInteractive'));
    on('after-interactive-callback', notify('afterInteractive'));
    on('unsupported-callback', notify('unsupported'));

    try {
      final id = api.render(_container, params);
      _widgetId = id;
      if (id != null) {
        _rendered = true;
        _post({'type': 'ready', 'widgetId': id.dartify()?.toString()});
        _reportSize();
      }
    } catch (error) {
      _post({'type': 'error', 'code': 'render_failed', 'message': '$error'});
    }
    return _widgetId;
  }

  void _post(Map<String, Object?> message) {
    final event = _decoder.decode(message);
    if (event != null) _emit(event);
  }

  void _emit(TurnstileEvent event) {
    if (!_closed) _events.add(event);
  }

  /// Flutter inserts platform views on its next frame, and browsers pause
  /// frames in background tabs: wait as long as needed. The session stops
  /// waiting when it is closed (widget removed).
  Future<void> _waitUntilConnected() async {
    while (!_container.isConnected && !_closed) {
      await Future<void>.delayed(_attachPollInterval);
    }
  }

  void _observeSize() {
    if (_resizeObserver != null) return;
    final observer = web.ResizeObserver(
      (JSArray<web.ResizeObserverEntry> _, web.ResizeObserver __) {
        _reportSize();
      }.toJS,
    );
    observer.observe(_container);
    _resizeObserver = observer;
  }

  void _reportSize() {
    // Before the first render the container is empty, and while Flutter
    // hides the platform view (scrolled away) it has no layout box: both
    // would report a misleading 0x0 and collapse the widget.
    if (_closed || !_rendered) return;
    if (_container.getClientRects().length == 0) return;
    final rect = _container.getBoundingClientRect();
    final size = (rect.width.ceil(), rect.height.ceil());
    // Turnstile inserts its iframe asynchronously: ignore empty sizes until a
    // real one has been seen. Later zero heights (remove, interaction-only)
    // are meaningful and reported.
    if (_lastSize == null && (size.$1 == 0 || size.$2 == 0)) return;
    if (size == _lastSize) return;
    _lastSize = size;
    _post({'type': 'resize', 'width': size.$1, 'height': size.$2});
  }
}
