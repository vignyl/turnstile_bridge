import '../core/turnstile_event.dart';
import 'turnstile_command.dart';

/// Source of events emitted by a running Turnstile page (JS to Dart).
abstract interface class TurnstileEventSource {
  /// Broadcast stream of decoded events. Closes when the session closes.
  Stream<TurnstileEvent> get events;
}

/// Executes commands inside a running Turnstile page (Dart to JS).
abstract interface class TurnstileCommandExecutor {
  /// Runs [command] and returns its raw JavaScript result.
  ///
  /// Throws a `TurnstileException` when the session is closed or the
  /// evaluation fails.
  Future<Object?> run(TurnstileCommand command);
}

/// A live, two-way connection to one Turnstile page.
///
/// `TurnstileController` depends on this abstraction only, so the WebView
/// engine can be swapped (or faked in tests) without touching it.
abstract interface class TurnstileSession
    implements TurnstileEventSource, TurnstileCommandExecutor {
  /// Reloads the whole Turnstile page.
  Future<void> reload();

  /// Removes the widget, unloads the page and closes the session.
  Future<void> destroy();

  /// Releases the bridge (handlers, streams) without touching the page.
  /// Idempotent.
  Future<void> close();
}
