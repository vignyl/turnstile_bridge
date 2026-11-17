import '../engine/turnstile_engine.dart';
import 'web_turnstile_engine.dart';

/// Default engine on Flutter web.
TurnstileEngine createDefaultTurnstileEngine() => const WebTurnstileEngine();
