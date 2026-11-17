import 'dart:convert';
import 'dart:ui' show Size;

import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';

/// Converts raw messages coming from JavaScript into [TurnstileEvent]s.
abstract interface class TurnstileMessageDecoder {
  /// Returns the decoded event, or `null` when [message] is not recognised.
  TurnstileEvent? decode(Object? message);
}

/// Default decoder for messages shaped like `{"type": "...", ...}`.
///
/// Accepts a map, a JSON string, or the argument list delivered by a
/// `flutter_inappwebview` JavaScript handler.
class JsonTurnstileMessageDecoder implements TurnstileMessageDecoder {
  /// Creates the decoder.
  const JsonTurnstileMessageDecoder({
    this.classifier = const TurnstileErrorClassifier(),
  });

  /// Classifier used for `error` messages.
  final TurnstileErrorClassifier classifier;

  @override
  TurnstileEvent? decode(Object? message) {
    final map = _asMap(message);
    if (map == null) return null;

    switch (map['type']) {
      case 'ready':
        return TurnstileLoaded(widgetId: map['widgetId']?.toString());
      case 'token':
        final token = map['token'];
        return token is String && token.isNotEmpty
            ? TurnstileTokenReceived(token)
            : null;
      case 'error':
        return TurnstileFailed(
          TurnstileError.fromCode(
            map['code']?.toString() ?? 'unknown',
            message: map['message']?.toString(),
            classifier: classifier,
          ),
        );
      case 'scriptError':
        return const TurnstileFailed(TurnstileError.scriptLoadFailed());
      case 'expired':
        return const TurnstileExpired();
      case 'timeout':
        return const TurnstileTimedOut();
      case 'beforeInteractive':
        return const TurnstileInteractionRequired();
      case 'afterInteractive':
        return const TurnstileInteractionCompleted();
      case 'unsupported':
        return const TurnstileUnsupported();
      case 'resize':
        final width = map['width'];
        final height = map['height'];
        if (width is num && height is num) {
          return TurnstileResized(Size(width.toDouble(), height.toDouble()));
        }
        return null;
      default:
        return null;
    }
  }

  Map<String, Object?>? _asMap(Object? message) {
    var value = message;
    if (value is List) {
      value = value.isEmpty ? null : value.first;
    }
    if (value is String) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        return null;
      }
    }
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
    }
    return null;
  }
}
