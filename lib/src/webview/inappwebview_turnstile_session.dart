import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../bridge/turnstile_command.dart';
import '../bridge/turnstile_js_api.dart';
import '../bridge/turnstile_message_decoder.dart';
import '../bridge/turnstile_session.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';

/// [TurnstileSession] backed by a `flutter_inappwebview` controller.
class InAppWebViewTurnstileSession implements TurnstileSession {
  /// Creates a session on [webViewController] serving [document].
  InAppWebViewTurnstileSession({
    required InAppWebViewController webViewController,
    required this.document,
    TurnstileMessageDecoder decoder = const JsonTurnstileMessageDecoder(),
  })  : _webView = webViewController,
        _decoder = decoder;

  final InAppWebViewController _webView;
  final TurnstileMessageDecoder _decoder;
  final StreamController<TurnstileEvent> _events =
      StreamController<TurnstileEvent>.broadcast();
  bool _closed = false;

  /// Page loaded by [reload].
  final InAppWebViewInitialData document;

  /// Whether [close] has been called.
  bool get isClosed => _closed;

  @override
  Stream<TurnstileEvent> get events => _events.stream;

  /// Registers the JavaScript handler. Must be called from
  /// `onWebViewCreated`, before the page loads.
  void attachJavaScriptHandler() {
    _webView.addJavaScriptHandler(
      handlerName: TurnstileJsApi.handlerName,
      callback: _onJavaScriptMessage,
    );
  }

  Object? _onJavaScriptMessage(List<dynamic> arguments) {
    final event = _decoder.decode(arguments);
    if (event != null) emit(event);
    return null;
  }

  /// Pushes [event] to listeners (used for native-side failures too).
  void emit(TurnstileEvent event) {
    if (!_closed) _events.add(event);
  }

  @override
  Future<Object?> run(TurnstileCommand command) async {
    if (_closed) throw const TurnstileException(TurnstileError.disposed());
    try {
      return await _webView.evaluateJavascript(source: command.script);
    } catch (error) {
      throw TurnstileException(TurnstileError.javascriptFailed('$error'));
    }
  }

  @override
  Future<void> reload() async {
    if (_closed) throw const TurnstileException(TurnstileError.disposed());
    await _webView.loadData(
      data: document.data,
      mimeType: document.mimeType,
      encoding: document.encoding,
      baseUrl: document.baseUrl,
    );
  }

  @override
  Future<void> destroy() async {
    if (_closed) return;
    try {
      await run(TurnstileCommand.remove);
      await _webView.loadUrl(urlRequest: URLRequest(url: WebUri('about:blank')));
    } on Object {
      // The WebView may already be gone; closing the bridge is what matters.
    }
    await close();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      _webView.removeJavaScriptHandler(handlerName: TurnstileJsApi.handlerName);
    } on Object {
      // Platform view already disposed.
    }
    await _events.close();
  }
}
