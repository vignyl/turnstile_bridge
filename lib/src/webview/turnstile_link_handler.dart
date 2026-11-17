import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Opens links that must leave the Turnstile WebView.
abstract interface class TurnstileLinkHandler {
  /// Opens [uri] outside of the WebView.
  Future<void> open(Uri uri);
}

/// Opens links in the system browser.
class SystemBrowserLinkHandler implements TurnstileLinkHandler {
  /// Creates the handler.
  const SystemBrowserLinkHandler();

  @override
  Future<void> open(Uri uri) =>
      InAppBrowser.openWithSystemBrowser(url: WebUri(uri.toString()));
}

/// Ignores every link. Useful for kiosks or tests.
class IgnoreLinkHandler implements TurnstileLinkHandler {
  /// Creates the handler.
  const IgnoreLinkHandler();

  @override
  Future<void> open(Uri uri) async {}
}
