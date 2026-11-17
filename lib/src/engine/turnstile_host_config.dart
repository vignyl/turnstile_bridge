import 'package:flutter/foundation.dart';

import '../core/turnstile_options.dart';
import '../html/turnstile_document_builder.dart';
import '../webview/turnstile_link_handler.dart';
import '../webview/turnstile_navigation_policy.dart';
import '../webview/turnstile_webview_config.dart';

/// Everything a [TurnstileEngine] needs to host one Turnstile widget.
///
/// Engines use the fields that make sense for them: the web engine renders
/// into the current page and ignores [baseUrl], [webViewConfig],
/// [documentBuilder], [linkHandler] and [navigationPolicy].
@immutable
class TurnstileHostConfig {
  /// Creates a configuration.
  const TurnstileHostConfig({
    required this.options,
    required this.baseUrl,
    this.webViewConfig = const TurnstileWebViewConfig(),
    this.documentBuilder = const TurnstileHtmlDocumentBuilder(),
    this.linkHandler = const SystemBrowserLinkHandler(),
    TurnstileNavigationPolicy? navigationPolicy,
  }) : _navigationPolicy = navigationPolicy;

  /// Turnstile configuration.
  final TurnstileOptions options;

  /// Origin of the hosting page (WebView engines only).
  final Uri baseUrl;

  /// WebView settings (WebView engines only).
  final TurnstileWebViewConfig webViewConfig;

  /// Generates the hosting page (WebView engines only).
  final TurnstileDocumentBuilder documentBuilder;

  /// Opens links leaving the page (WebView engines only).
  final TurnstileLinkHandler linkHandler;

  final TurnstileNavigationPolicy? _navigationPolicy;

  /// Navigation rules (WebView engines only).
  TurnstileNavigationPolicy get navigationPolicy =>
      _navigationPolicy ?? DefaultTurnstileNavigationPolicy(baseUri: baseUrl);

  @override
  bool operator ==(Object other) =>
      other is TurnstileHostConfig &&
      other.options == options &&
      other.baseUrl == baseUrl &&
      other.webViewConfig == webViewConfig &&
      other.documentBuilder == documentBuilder &&
      other.linkHandler == linkHandler &&
      other._navigationPolicy == _navigationPolicy;

  @override
  int get hashCode => Object.hash(
        options,
        baseUrl,
        webViewConfig,
        documentBuilder,
        linkHandler,
        _navigationPolicy,
      );
}
