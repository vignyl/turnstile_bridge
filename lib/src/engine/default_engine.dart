/// Selects the engine for the current platform at compile time.
library;

export 'default_engine_stub.dart'
    if (dart.library.js_interop) '../web/web_default_engine.dart'
    if (dart.library.io) '../webview/inappwebview_default_engine.dart';
