import 'package:flutter/foundation.dart';

/// Families of Turnstile failures, used to decide how the app should react.
enum TurnstileErrorCategory {
  /// Turnstile could not initialise (outdated page, API incompatibility).
  initialization(isRetryable: false),

  /// Wrong site key, unauthorised hostname, invalid `action` or `cData`.
  invalidConfiguration(isRetryable: false),

  /// The WebView or its user agent is not supported by Turnstile.
  unsupportedEnvironment(isRetryable: false),

  /// The device clock is wrong.
  clockSkew(isRetryable: false),

  /// The challenge or the interactive step timed out.
  challengeTimeout(isRetryable: true),

  /// The visitor failed the challenge (possibly a bot).
  challengeFailed(isRetryable: true),

  /// Generic client-side execution error.
  clientExecution(isRetryable: true),

  /// The page or the Turnstile script could not be loaded.
  network(isRetryable: true),

  /// Misuse of this package (controller not attached, disposed, ...).
  bridge(isRetryable: false),

  /// Unrecognised error code.
  unknown(isRetryable: true);

  const TurnstileErrorCategory({required this.isRetryable});

  /// Whether calling `reset` has a reasonable chance to succeed.
  final bool isRetryable;
}

/// Maps a Turnstile client-side error code to a [TurnstileErrorCategory].
///
/// Based on the
/// [client-side error codes](https://developers.cloudflare.com/turnstile/troubleshooting/client-side-errors/error-codes/).
/// Extend this class and override [classify] to refine the mapping.
class TurnstileErrorClassifier {
  /// Creates the default classifier.
  const TurnstileErrorClassifier();

  static const Map<String, TurnstileErrorCategory> _exact = {
    '110100': TurnstileErrorCategory.invalidConfiguration,
    '110110': TurnstileErrorCategory.invalidConfiguration,
    '110200': TurnstileErrorCategory.invalidConfiguration,
    '110420': TurnstileErrorCategory.invalidConfiguration,
    '110430': TurnstileErrorCategory.invalidConfiguration,
    '110500': TurnstileErrorCategory.unsupportedEnvironment,
    '110510': TurnstileErrorCategory.unsupportedEnvironment,
    '200010': TurnstileErrorCategory.initialization,
    '200100': TurnstileErrorCategory.clockSkew,
  };

  static const List<(String, TurnstileErrorCategory)> _prefixes = [
    ('11060', TurnstileErrorCategory.challengeTimeout),
    ('11062', TurnstileErrorCategory.challengeTimeout),
    ('100', TurnstileErrorCategory.initialization),
    ('105', TurnstileErrorCategory.initialization),
    ('102', TurnstileErrorCategory.clientExecution),
    ('103', TurnstileErrorCategory.clientExecution),
    ('104', TurnstileErrorCategory.clientExecution),
    ('106', TurnstileErrorCategory.clientExecution),
    ('120', TurnstileErrorCategory.clientExecution),
    ('300', TurnstileErrorCategory.clientExecution),
    ('400', TurnstileErrorCategory.invalidConfiguration),
    ('600', TurnstileErrorCategory.challengeFailed),
  ];

  /// Returns the category of [code].
  TurnstileErrorCategory classify(String code) {
    final exact = _exact[code];
    if (exact != null) return exact;
    for (final (prefix, category) in _prefixes) {
      if (code.startsWith(prefix)) return category;
    }
    return TurnstileErrorCategory.unknown;
  }
}

/// A failure reported by Turnstile or by this package.
@immutable
class TurnstileError {
  /// Creates an error.
  const TurnstileError({
    required this.code,
    required this.category,
    this.message,
  });

  /// Builds an error from a Turnstile error code.
  factory TurnstileError.fromCode(
    String code, {
    String? message,
    TurnstileErrorClassifier classifier = const TurnstileErrorClassifier(),
  }) {
    return TurnstileError(
      code: code,
      category: classifier.classify(code),
      message: message,
    );
  }

  /// The Turnstile script (`api.js`) could not be downloaded.
  const TurnstileError.scriptLoadFailed()
      : code = scriptLoadFailedCode,
        category = TurnstileErrorCategory.network,
        message = 'The Turnstile script could not be loaded.';

  /// The WebView could not load the host page.
  const TurnstileError.pageLoadFailed([this.message])
      : code = pageLoadFailedCode,
        category = TurnstileErrorCategory.network;

  /// The widget was not rendered within the configured load timeout.
  const TurnstileError.loadTimeout()
      : code = loadTimeoutCode,
        category = TurnstileErrorCategory.network,
        message = 'Turnstile did not render within the load timeout.';

  /// The WebView reported that Turnstile is not supported.
  const TurnstileError.unsupported()
      : code = unsupportedCode,
        category = TurnstileErrorCategory.unsupportedEnvironment,
        message = 'Turnstile is not supported in this WebView.';

  /// An interactive challenge was required where none can be shown.
  const TurnstileError.interactionRequired()
      : code = interactionRequiredCode,
        category = TurnstileErrorCategory.bridge,
        message = 'An interactive challenge is required; '
            'display a TurnstileWidget instead of the headless mode.';

  /// No token was received within the time given to `waitForToken`.
  const TurnstileError.tokenTimeout()
      : code = tokenTimeoutCode,
        category = TurnstileErrorCategory.challengeTimeout,
        message = 'No token was received in time.';

  /// A command was sent while no WebView is attached.
  const TurnstileError.notAttached()
      : code = notAttachedCode,
        category = TurnstileErrorCategory.bridge,
        message = 'The controller is not attached to a Turnstile WebView.';

  /// The controller or session was used after being disposed.
  const TurnstileError.disposed()
      : code = disposedCode,
        category = TurnstileErrorCategory.bridge,
        message = 'The Turnstile controller or session has been disposed.';

  /// Evaluating JavaScript in the WebView failed.
  const TurnstileError.javascriptFailed([this.message])
      : code = javascriptFailedCode,
        category = TurnstileErrorCategory.bridge;

  /// [code] of [TurnstileError.scriptLoadFailed].
  static const String scriptLoadFailedCode = 'script_load_failed';

  /// [code] of [TurnstileError.pageLoadFailed].
  static const String pageLoadFailedCode = 'page_load_failed';

  /// [code] of [TurnstileError.loadTimeout].
  static const String loadTimeoutCode = 'load_timeout';

  /// [code] of [TurnstileError.unsupported].
  static const String unsupportedCode = 'unsupported';

  /// [code] of [TurnstileError.interactionRequired].
  static const String interactionRequiredCode = 'interaction_required';

  /// [code] of [TurnstileError.tokenTimeout].
  static const String tokenTimeoutCode = 'token_timeout';

  /// [code] of [TurnstileError.notAttached].
  static const String notAttachedCode = 'not_attached';

  /// [code] of [TurnstileError.disposed].
  static const String disposedCode = 'disposed';

  /// [code] of [TurnstileError.javascriptFailed].
  static const String javascriptFailedCode = 'javascript_failed';

  /// Turnstile numeric code (`110200`, ...) or one of this class's constants.
  final String code;

  /// Family of the failure.
  final TurnstileErrorCategory category;

  /// Optional human readable details.
  final String? message;

  /// Shortcut for `category.isRetryable`.
  bool get isRetryable => category.isRetryable;

  @override
  bool operator ==(Object other) =>
      other is TurnstileError &&
      other.code == code &&
      other.category == category &&
      other.message == message;

  @override
  int get hashCode => Object.hash(code, category, message);

  @override
  String toString() =>
      'TurnstileError($code, ${category.name}${message == null ? '' : ', $message'})';
}

/// Exception thrown by asynchronous controller methods.
class TurnstileException implements Exception {
  /// Wraps [error].
  const TurnstileException(this.error);

  /// The underlying error.
  final TurnstileError error;

  @override
  String toString() => 'TurnstileException: $error';
}
