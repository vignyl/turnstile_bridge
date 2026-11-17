import '../engine/turnstile_engine.dart';
import 'inappwebview_turnstile_engine.dart';

/// Default engine on native platforms.
TurnstileEngine createDefaultTurnstileEngine() =>
    const InAppWebViewTurnstileEngine();
