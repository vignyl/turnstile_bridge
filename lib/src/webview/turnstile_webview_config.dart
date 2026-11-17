import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// WebView settings tuned for Turnstile.
///
/// Turnstile relies on cookies and local storage on both the host page and
/// the `challenges.cloudflare.com` iframe. These settings keep them enabled and
/// persistent (no incognito, third-party cookies allowed on Android, shared
/// cookie store on iOS) so that clearance survives between sessions.
@immutable
class TurnstileWebViewConfig {
  /// Creates a configuration.
  const TurnstileWebViewConfig({
    this.userAgent,
    this.inspectable = kDebugMode,
    this.transparentBackground = true,
  });

  /// Custom user agent. Leave `null`: a user agent that does not match the
  /// real engine triggers Turnstile error `110510`.
  final String? userAgent;

  /// Allows Safari / Chrome DevTools to inspect the WebView.
  final bool inspectable;

  /// Lets the Flutter background show through the page.
  final bool transparentBackground;

  /// Builds the `flutter_inappwebview` settings.
  InAppWebViewSettings toSettings() => InAppWebViewSettings(
        // JavaScript and persistent storage.
        javaScriptEnabled: true,
        domStorageEnabled: true,
        databaseEnabled: true,
        incognito: false,
        cacheEnabled: true,
        thirdPartyCookiesEnabled: true,
        sharedCookiesEnabled: true,
        // Navigation control (links open in the system browser).
        useShouldOverrideUrlLoading: true,
        supportMultipleWindows: true,
        javaScriptCanOpenWindowsAutomatically: true,
        // Looks like a native widget.
        transparentBackground: transparentBackground,
        supportZoom: false,
        disableContextMenu: true,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        allowsLinkPreview: false,
        isInspectable: inspectable,
        userAgent: userAgent,
      );

  @override
  bool operator ==(Object other) =>
      other is TurnstileWebViewConfig &&
      other.userAgent == userAgent &&
      other.inspectable == inspectable &&
      other.transparentBackground == transparentBackground;

  @override
  int get hashCode => Object.hash(userAgent, inspectable, transparentBackground);
}
