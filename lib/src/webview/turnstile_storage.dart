import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Clears what Turnstile persists between sessions.
///
/// Cookies and storage are persistent by default, which is what Turnstile
/// needs. Clear them only on explicit user action (logout, privacy reset).
abstract interface class TurnstileStorage {
  /// Clears cookies and website data.
  Future<void> clear();
}

/// [TurnstileStorage] for the WebView engine (`flutter_inappwebview`).
///
/// Warning: the WebView cookie store and website data are shared by every
/// WebView of the app, not only Turnstile. On the web this is a no-op: the
/// browser owns the site's cookies and Turnstile's own storage is
/// cross-origin.
class InAppWebViewTurnstileStorage implements TurnstileStorage {
  /// Creates the storage helper.
  const InAppWebViewTurnstileStorage();

  /// Deletes every WebView cookie.
  Future<void> clearCookies() async {
    if (kIsWeb) return;
    await CookieManager.instance().deleteAllCookies();
  }

  /// Deletes local storage, IndexedDB and caches where the platform allows.
  Future<void> clearWebsiteData() async {
    if (kIsWeb) return;
    final manager = WebStorageManager.instance();
    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          await manager.removeDataModifiedSince(
            dataTypes: WebsiteDataType.ALL.toSet(),
            date: DateTime.fromMillisecondsSinceEpoch(0),
          );
        case TargetPlatform.android:
        case TargetPlatform.windows:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          await manager.deleteAllData();
      }
    } on UnimplementedError {
      // Not supported by this platform implementation; cookies still cleared.
    }
  }

  @override
  Future<void> clear() async {
    await clearCookies();
    await clearWebsiteData();
  }
}
