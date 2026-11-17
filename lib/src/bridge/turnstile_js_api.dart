/// Names shared by the Dart side and the generated JavaScript.
///
/// Keeping them in one place guarantees both sides of the bridge agree.
abstract final class TurnstileJsApi {
  /// Name of the `flutter_inappwebview` handler receiving JS messages.
  static const String handlerName = 'TurnstileBridge';

  /// Global JavaScript object exposing the Dart-to-JS commands.
  static const String globalObject = '__turnstileBridge';

  /// DOM id of the element Turnstile renders into.
  static const String containerId = 'turnstile-container';
}
