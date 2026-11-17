import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../bridge/turnstile_message_decoder.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';
import '../core/turnstile_options.dart';
import '../html/turnstile_document_builder.dart';
import 'inappwebview_turnstile_session.dart';
import 'turnstile_link_handler.dart';
import 'turnstile_navigation_policy.dart';

/// Builds the `flutter_inappwebview` initial data for a Turnstile page.
InAppWebViewInitialData createTurnstileDocument({
  required TurnstileOptions options,
  required Uri baseUrl,
  required TurnstileDocumentBuilder builder,
}) {
  return InAppWebViewInitialData(
    data: builder.build(options),
    mimeType: 'text/html',
    encoding: 'utf-8',
    baseUrl: WebUri(baseUrl.toString()),
  );
}

/// Wires one WebView (visible or headless) to an
/// [InAppWebViewTurnstileSession].
///
/// `InAppWebView` and `HeadlessInAppWebView` share the same callback
/// signatures, so both use this single implementation.
class TurnstileWebViewDelegate {
  /// Creates a delegate.
  TurnstileWebViewDelegate({
    required this.document,
    required this.navigationPolicy,
    required this.linkHandler,
    required this.onSessionCreated,
    this.decoder = const JsonTurnstileMessageDecoder(),
  });

  /// Page served by the WebView.
  final InAppWebViewInitialData document;

  /// Navigation rules.
  final TurnstileNavigationPolicy navigationPolicy;

  /// Opens external links.
  final TurnstileLinkHandler linkHandler;

  /// Called once the WebView exists and the bridge is ready.
  final void Function(InAppWebViewTurnstileSession session) onSessionCreated;

  /// Decoder used by the session.
  final TurnstileMessageDecoder decoder;

  InAppWebViewTurnstileSession? _session;

  /// The current session, if the WebView has been created.
  InAppWebViewTurnstileSession? get session => _session;

  /// `onWebViewCreated` callback.
  void onWebViewCreated(InAppWebViewController controller) {
    final session = InAppWebViewTurnstileSession(
      webViewController: controller,
      document: document,
      decoder: decoder,
    )..attachJavaScriptHandler();
    _session = session;
    onSessionCreated(session);
  }

  /// `shouldOverrideUrlLoading` callback.
  Future<NavigationActionPolicy?> shouldOverrideUrlLoading(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    final decision = navigationPolicy.decide(
      uri: uri,
      isMainFrame: action.isForMainFrame,
    );
    switch (decision) {
      case TurnstileNavigationDecision.allow:
        return NavigationActionPolicy.ALLOW;
      case TurnstileNavigationDecision.openExternally:
        if (uri != null) unawaited(_openSafely(uri));
        return NavigationActionPolicy.CANCEL;
      case TurnstileNavigationDecision.block:
        return NavigationActionPolicy.CANCEL;
    }
  }

  /// `onCreateWindow` callback: `target="_blank"` links (privacy, terms).
  Future<bool?> onCreateWindow(
    InAppWebViewController controller,
    CreateWindowAction action,
  ) async {
    final uri = action.request.url;
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      unawaited(_openSafely(uri));
    }
    return false;
  }

  /// `onReceivedError` callback: reports main-frame load failures.
  void onReceivedError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    if (request.isForMainFrame ?? false) {
      _session?.emit(
        TurnstileFailed(TurnstileError.pageLoadFailed(error.description)),
      );
    }
  }

  Future<void> _openSafely(Uri uri) async {
    try {
      await linkHandler.open(uri);
    } on Object {
      // Opening a link must never break the challenge.
    }
  }
}
