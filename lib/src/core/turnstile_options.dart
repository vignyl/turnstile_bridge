import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

/// Visual theme of the Turnstile widget.
enum TurnstileTheme {
  /// Follows the visitor's system preference.
  auto('auto'),

  /// Always light.
  light('light'),

  /// Always dark.
  dark('dark');

  const TurnstileTheme(this.value);

  /// Value expected by the Turnstile JavaScript API.
  final String value;
}

/// Size of the Turnstile widget.
enum TurnstileSize {
  /// 300 x 65 px.
  normal('normal', Size(300, 65)),

  /// Takes the full available width (minimum 300 px), 65 px high.
  flexible('flexible', Size(300, 65)),

  /// 150 x 140 px.
  compact('compact', Size(150, 140));

  const TurnstileSize(this.value, this.preferredSize);

  /// Value expected by the Turnstile JavaScript API.
  final String value;

  /// Size the widget occupies before Turnstile reports its real size.
  final Size preferredSize;
}

/// Controls when the widget becomes visible.
enum TurnstileAppearance {
  /// The widget is always visible.
  always('always'),

  /// The widget is visible only while a challenge is executing.
  execute('execute'),

  /// The widget is visible only when an interaction is required.
  interactionOnly('interaction-only');

  const TurnstileAppearance(this.value);

  /// Value expected by the Turnstile JavaScript API.
  final String value;
}

/// Controls when the challenge runs.
enum TurnstileExecution {
  /// The challenge runs as soon as the widget is rendered.
  render('render'),

  /// The challenge waits for `TurnstileController.execute`.
  execute('execute');

  const TurnstileExecution(this.value);

  /// Value expected by the Turnstile JavaScript API.
  final String value;
}

/// Retry behaviour when a challenge fails.
enum TurnstileRetry {
  /// Turnstile retries automatically.
  auto('auto'),

  /// Turnstile never retries; the app decides.
  never('never');

  const TurnstileRetry(this.value);

  /// Value expected by the Turnstile JavaScript API.
  final String value;
}

/// Behaviour when a token expires or an interactive challenge times out.
enum TurnstileRefreshMode {
  /// Turnstile refreshes automatically.
  auto('auto'),

  /// The visitor is asked to refresh.
  manual('manual'),

  /// Nothing happens; the app must call `reset`.
  never('never');

  const TurnstileRefreshMode(this.value);

  /// Value expected by the Turnstile JavaScript API.
  final String value;
}

/// Immutable configuration of a Turnstile widget.
///
/// Maps one to one to the
/// [Turnstile render parameters](https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/#configurations).
@immutable
class TurnstileOptions {
  /// Creates a configuration. Only [siteKey] is required.
  const TurnstileOptions({
    required this.siteKey,
    this.action,
    this.cData,
    this.theme = TurnstileTheme.auto,
    this.size = TurnstileSize.normal,
    this.language = 'auto',
    this.appearance = TurnstileAppearance.always,
    this.execution = TurnstileExecution.render,
    this.retry = TurnstileRetry.auto,
    this.retryInterval = const Duration(seconds: 8),
    this.refreshExpired = TurnstileRefreshMode.auto,
    this.refreshTimeout = TurnstileRefreshMode.auto,
    this.feedbackEnabled = true,
  });

  /// Public site key from the Cloudflare dashboard.
  final String siteKey;

  /// Optional action name (max 32 chars, `[A-Za-z0-9_-]`), returned by
  /// siteverify. Useful to distinguish widgets server-side.
  final String? action;

  /// Optional customer data (max 255 chars, `[A-Za-z0-9_-]`), returned by
  /// siteverify.
  final String? cData;

  /// Visual theme.
  final TurnstileTheme theme;

  /// Widget size.
  final TurnstileSize size;

  /// ISO 639-1 language code (`fr`, `pt-BR`, ...) or `auto`.
  final String language;

  /// When the widget is visible.
  final TurnstileAppearance appearance;

  /// When the challenge runs.
  final TurnstileExecution execution;

  /// Automatic retry behaviour.
  final TurnstileRetry retry;

  /// Delay between automatic retries (must be below 15 minutes).
  final Duration retryInterval;

  /// What happens when the token expires.
  final TurnstileRefreshMode refreshExpired;

  /// What happens when an interactive challenge times out.
  final TurnstileRefreshMode refreshTimeout;

  /// Whether Cloudflare may ask the visitor for feedback on failure.
  final bool feedbackEnabled;

  static final RegExp _token = RegExp(r'^[A-Za-z0-9_-]*$');
  static final RegExp _language = RegExp(r'^[a-zA-Z]{2,3}(-[a-zA-Z]{2,4})?$');

  /// Returns the list of problems with this configuration (empty when valid).
  List<String> validate() {
    final problems = <String>[];
    if (siteKey.trim().isEmpty) {
      problems.add('siteKey must not be empty.');
    }
    final action = this.action;
    if (action != null && (action.length > 32 || !_token.hasMatch(action))) {
      problems.add('action must be at most 32 characters of [A-Za-z0-9_-].');
    }
    final cData = this.cData;
    if (cData != null && (cData.length > 255 || !_token.hasMatch(cData))) {
      problems.add('cData must be at most 255 characters of [A-Za-z0-9_-].');
    }
    if (language != 'auto' && !_language.hasMatch(language)) {
      problems.add('language must be "auto" or an ISO 639-1 code like "fr".');
    }
    final retryMs = retryInterval.inMilliseconds;
    if (retryMs <= 0 || retryMs >= 900000) {
      problems.add('retryInterval must be between 1 ms and 15 minutes.');
    }
    return problems;
  }

  /// Throws an [ArgumentError] when [validate] reports a problem.
  void ensureValid() {
    final problems = validate();
    if (problems.isNotEmpty) {
      throw ArgumentError(problems.join(' '), 'options');
    }
  }

  /// Render parameters passed to `turnstile.render`, callbacks excluded.
  Map<String, Object> toRenderParameters() => <String, Object>{
        'sitekey': siteKey,
        if (action != null) 'action': action!,
        if (cData != null) 'cData': cData!,
        'theme': theme.value,
        'size': size.value,
        'language': language,
        'appearance': appearance.value,
        'execution': execution.value,
        'retry': retry.value,
        'retry-interval': retryInterval.inMilliseconds,
        'refresh-expired': refreshExpired.value,
        'refresh-timeout': refreshTimeout.value,
        'feedback-enabled': feedbackEnabled,
      };

  /// Returns a copy with the given fields replaced.
  TurnstileOptions copyWith({
    String? siteKey,
    String? action,
    String? cData,
    TurnstileTheme? theme,
    TurnstileSize? size,
    String? language,
    TurnstileAppearance? appearance,
    TurnstileExecution? execution,
    TurnstileRetry? retry,
    Duration? retryInterval,
    TurnstileRefreshMode? refreshExpired,
    TurnstileRefreshMode? refreshTimeout,
    bool? feedbackEnabled,
  }) {
    return TurnstileOptions(
      siteKey: siteKey ?? this.siteKey,
      action: action ?? this.action,
      cData: cData ?? this.cData,
      theme: theme ?? this.theme,
      size: size ?? this.size,
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      execution: execution ?? this.execution,
      retry: retry ?? this.retry,
      retryInterval: retryInterval ?? this.retryInterval,
      refreshExpired: refreshExpired ?? this.refreshExpired,
      refreshTimeout: refreshTimeout ?? this.refreshTimeout,
      feedbackEnabled: feedbackEnabled ?? this.feedbackEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TurnstileOptions &&
          other.siteKey == siteKey &&
          other.action == action &&
          other.cData == cData &&
          other.theme == theme &&
          other.size == size &&
          other.language == language &&
          other.appearance == appearance &&
          other.execution == execution &&
          other.retry == retry &&
          other.retryInterval == retryInterval &&
          other.refreshExpired == refreshExpired &&
          other.refreshTimeout == refreshTimeout &&
          other.feedbackEnabled == feedbackEnabled;

  @override
  int get hashCode => Object.hash(
        siteKey,
        action,
        cData,
        theme,
        size,
        language,
        appearance,
        execution,
        retry,
        retryInterval,
        refreshExpired,
        refreshTimeout,
        feedbackEnabled,
      );

  @override
  String toString() => 'TurnstileOptions(${toRenderParameters()})';
}
