import 'turnstile_engine.dart';

/// Fallback used when neither `dart:io` nor `dart:js_interop` is available.
TurnstileEngine createDefaultTurnstileEngine() => throw UnsupportedError(
      'turnstile_bridge has no engine for this platform. '
      'Pass a custom TurnstileEngine.',
    );
