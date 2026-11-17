/// What to do with a navigation request coming from the Turnstile page.
enum TurnstileNavigationDecision {
  /// Let the WebView navigate.
  allow,

  /// Cancel and open the URL with the link handler (system browser).
  openExternally,

  /// Cancel silently.
  block,
}

/// Decides which navigations the Turnstile WebView may perform.
abstract interface class TurnstileNavigationPolicy {
  /// Returns the decision for [uri].
  TurnstileNavigationDecision decide({
    required Uri? uri,
    required bool isMainFrame,
  });
}

/// Keeps the main frame on the host page and sends other links (privacy
/// policy, terms) to the system browser. Sub-frames, used by the Turnstile
/// iframe, are always allowed.
class DefaultTurnstileNavigationPolicy implements TurnstileNavigationPolicy {
  /// Creates the policy for a page loaded at [baseUri].
  const DefaultTurnstileNavigationPolicy({required this.baseUri});

  /// Origin of the host page.
  final Uri baseUri;

  static const Set<String> _internalSchemes = {'about', 'data', 'blob'};

  @override
  TurnstileNavigationDecision decide({
    required Uri? uri,
    required bool isMainFrame,
  }) {
    if (uri == null) return TurnstileNavigationDecision.block;
    final scheme = uri.scheme.toLowerCase();
    if (_internalSchemes.contains(scheme)) {
      return TurnstileNavigationDecision.allow;
    }
    if (scheme != 'http' && scheme != 'https') {
      return TurnstileNavigationDecision.block;
    }
    if (!isMainFrame || _sameOrigin(uri)) {
      return TurnstileNavigationDecision.allow;
    }
    return TurnstileNavigationDecision.openExternally;
  }

  bool _sameOrigin(Uri uri) =>
      uri.scheme.toLowerCase() == baseUri.scheme.toLowerCase() &&
      uri.host.toLowerCase() == baseUri.host.toLowerCase() &&
      uri.port == baseUri.port;
}
