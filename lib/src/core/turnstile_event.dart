import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import 'turnstile_error.dart';

/// Base type of everything the Turnstile JavaScript runtime reports.
///
/// The hierarchy is sealed so that a `switch` over events is exhaustive:
///
/// ```dart
/// switch (event) {
///   case TurnstileTokenReceived(:final token): send(token);
///   case TurnstileFailed(:final error): log(error);
///   default: break;
/// }
/// ```
@immutable
sealed class TurnstileEvent {
  const TurnstileEvent();
}

/// The widget has been rendered and the challenge is starting.
final class TurnstileLoaded extends TurnstileEvent {
  /// Creates the event.
  const TurnstileLoaded({this.widgetId});

  /// Identifier returned by `turnstile.render`.
  final String? widgetId;

  @override
  bool operator ==(Object other) =>
      other is TurnstileLoaded && other.widgetId == widgetId;

  @override
  int get hashCode => Object.hash(TurnstileLoaded, widgetId);

  @override
  String toString() => 'TurnstileLoaded($widgetId)';
}

/// The challenge succeeded. Send [token] to your backend for validation.
final class TurnstileTokenReceived extends TurnstileEvent {
  /// Creates the event.
  const TurnstileTokenReceived(this.token);

  /// Single-use token, valid for 300 seconds.
  final String token;

  @override
  bool operator ==(Object other) =>
      other is TurnstileTokenReceived && other.token == token;

  @override
  int get hashCode => Object.hash(TurnstileTokenReceived, token);

  @override
  String toString() => 'TurnstileTokenReceived(${token.length} chars)';
}

/// Turnstile or the bridge reported an error.
final class TurnstileFailed extends TurnstileEvent {
  /// Creates the event.
  const TurnstileFailed(this.error);

  /// What went wrong.
  final TurnstileError error;

  @override
  bool operator ==(Object other) =>
      other is TurnstileFailed && other.error == error;

  @override
  int get hashCode => Object.hash(TurnstileFailed, error);

  @override
  String toString() => 'TurnstileFailed($error)';
}

/// The previously issued token expired.
final class TurnstileExpired extends TurnstileEvent {
  /// Creates the event.
  const TurnstileExpired();

  @override
  bool operator ==(Object other) => other is TurnstileExpired;

  @override
  int get hashCode => (TurnstileExpired).hashCode;

  @override
  String toString() => 'TurnstileExpired()';
}

/// The interactive challenge was not solved in time.
final class TurnstileTimedOut extends TurnstileEvent {
  /// Creates the event.
  const TurnstileTimedOut();

  @override
  bool operator ==(Object other) => other is TurnstileTimedOut;

  @override
  int get hashCode => (TurnstileTimedOut).hashCode;

  @override
  String toString() => 'TurnstileTimedOut()';
}

/// Turnstile needs the visitor to interact (checkbox).
final class TurnstileInteractionRequired extends TurnstileEvent {
  /// Creates the event.
  const TurnstileInteractionRequired();

  @override
  bool operator ==(Object other) => other is TurnstileInteractionRequired;

  @override
  int get hashCode => (TurnstileInteractionRequired).hashCode;

  @override
  String toString() => 'TurnstileInteractionRequired()';
}

/// The visitor finished the interactive step.
final class TurnstileInteractionCompleted extends TurnstileEvent {
  /// Creates the event.
  const TurnstileInteractionCompleted();

  @override
  bool operator ==(Object other) => other is TurnstileInteractionCompleted;

  @override
  int get hashCode => (TurnstileInteractionCompleted).hashCode;

  @override
  String toString() => 'TurnstileInteractionCompleted()';
}

/// Turnstile reports that this WebView is not supported.
final class TurnstileUnsupported extends TurnstileEvent {
  /// Creates the event.
  const TurnstileUnsupported();

  @override
  bool operator ==(Object other) => other is TurnstileUnsupported;

  @override
  int get hashCode => (TurnstileUnsupported).hashCode;

  @override
  String toString() => 'TurnstileUnsupported()';
}

/// The rendered widget changed size (logical pixels).
final class TurnstileResized extends TurnstileEvent {
  /// Creates the event.
  const TurnstileResized(this.size);

  /// New size of the Turnstile container.
  final Size size;

  @override
  bool operator ==(Object other) =>
      other is TurnstileResized && other.size == size;

  @override
  int get hashCode => Object.hash(TurnstileResized, size);

  @override
  String toString() => 'TurnstileResized($size)';
}
