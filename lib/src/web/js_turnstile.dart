import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../core/turnstile_error.dart';

/// The global `turnstile` object defined by `api.js`, or `null` before load.
@JS('turnstile')
external JsTurnstile? get jsTurnstile;

/// Binding to the Turnstile JavaScript API.
extension type JsTurnstile._(JSObject _) implements JSObject {
  /// `turnstile.render(container, params)`.
  external JSAny? render(JSAny container, JSObject params);

  /// `turnstile.reset(widgetId)`.
  external void reset(JSAny widgetId);

  /// `turnstile.remove(widgetId)`.
  external void remove(JSAny widgetId);

  /// `turnstile.execute(container)`.
  external void execute(JSAny container);

  /// `turnstile.getResponse(widgetId)`.
  external JSAny? getResponse(JSAny widgetId);

  /// `turnstile.isExpired(widgetId)`.
  external JSAny? isExpired(JSAny widgetId);
}

/// Injects `api.js` once per page and completes when it is ready.
abstract final class TurnstileScriptLoader {
  static const String _callbackName = '__turnstileBridgeOnLoad';
  static Future<void>? _loading;

  /// Loads the script from [scriptUrl] unless it is already available.
  ///
  /// Throws a [TurnstileException] with [TurnstileError.scriptLoadFailed]
  /// when the script cannot be downloaded; a later call retries.
  static Future<void> ensureLoaded(String scriptUrl) {
    if (jsTurnstile != null) return Future<void>.value();
    final pending = _loading ??= _load(scriptUrl);
    return pending.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_loading, pending)) _loading = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  static Future<void> _load(String scriptUrl) {
    final completer = Completer<void>();
    globalContext.setProperty(
      _callbackName.toJS,
      () {
        if (!completer.isCompleted) completer.complete();
      }.toJS,
    );
    final script = web.HTMLScriptElement()
      ..src = '$scriptUrl?render=explicit&onload=$_callbackName'
      ..async = true
      ..defer = true;
    script.onerror = (web.Event _) {
      script.remove();
      if (!completer.isCompleted) {
        completer.completeError(
          const TurnstileException(TurnstileError.scriptLoadFailed()),
        );
      }
    }.toJS;
    web.document.head!.append(script);
    return completer.future;
  }
}
