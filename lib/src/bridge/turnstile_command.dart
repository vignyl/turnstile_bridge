import 'turnstile_js_api.dart';

/// Commands sent from Dart to the Turnstile JavaScript runtime.
enum TurnstileCommand {
  /// Renders the widget if it is not rendered yet.
  render('render'),

  /// Resets the widget and starts a new challenge.
  reset('reset'),

  /// Removes the widget from the page.
  remove('remove'),

  /// Runs the challenge (with `TurnstileExecution.execute`).
  execute('execute'),

  /// Returns the current token, or `null`.
  getResponse('getResponse'),

  /// Returns whether the current token is expired.
  isExpired('isExpired');

  const TurnstileCommand(this.functionName);

  /// Name of the function on the global bridge object.
  final String functionName;

  /// JavaScript expression evaluating the command. It is a no-op returning
  /// `null` when the bridge object is not defined yet.
  String get script {
    const bridge = 'window.${TurnstileJsApi.globalObject}';
    return '($bridge ? $bridge.$functionName() : null)';
  }
}
