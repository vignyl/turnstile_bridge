/// Lifecycle state of a `TurnstileController`.
enum TurnstileStatus {
  /// Not attached to a WebView, or the widget was removed.
  idle,

  /// The page or the challenge is loading.
  loading,

  /// The widget is rendered; the challenge is running or waiting for
  /// `execute`.
  ready,

  /// The visitor must interact with the widget.
  interactive,

  /// A valid token is available.
  verified,

  /// The token expired; call `reset` (unless refresh is automatic).
  expired,

  /// The interactive challenge timed out.
  timedOut,

  /// An error occurred; see `TurnstileController.lastError`.
  failed,

  /// Turnstile does not support this WebView.
  unsupported,

  /// The WebView was destroyed with `destroy`; call `recreate` to show it
  /// again.
  destroyed,

  /// The controller was disposed and can no longer be used.
  disposed,
}
