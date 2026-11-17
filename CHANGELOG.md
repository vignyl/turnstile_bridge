## 0.1.0

First release.

- `TurnstileWidget` shows the widget and follows its size changes.
- `TurnstileHeadless` gets tokens from invisible site keys without any UI.
- `TurnstileController` exposes `reset`, `remove`, `render`, `execute`, `reload`, `destroy`, `recreate`, `getResponse`, `isExpired` and `waitForToken`, plus its state and an event stream.
- Runs on Android, iOS, macOS, Windows and Linux through `flutter_inappwebview`, and directly in the page on the web. Linux is experimental.
- Turnstile error codes are grouped into categories with an `isRetryable` flag.
- Cookies and storage persist between launches. `InAppWebViewTurnstileStorage` clears them.
- The HTML page, navigation rules, link handling and message decoding can each be replaced.
- Requires `flutter_inappwebview` 6.2.0 (beta) because 6.1.5 doesn't build with Android Gradle Plugin 9.
