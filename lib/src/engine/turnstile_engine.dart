import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../bridge/turnstile_session.dart';
import 'turnstile_host_config.dart';

/// Called by an engine once its [TurnstileSession] is ready.
typedef TurnstileSessionCallback = void Function(TurnstileSession session);

/// Hosts Turnstile on one platform family.
///
/// `TurnstileWidget` and `TurnstileHeadless` only talk to this interface, so
/// supporting a new platform means adding an engine, not changing them.
///
/// Built-in engines:
/// * `InAppWebViewTurnstileEngine`: Android, iOS, macOS, Windows, Linux.
/// * `WebTurnstileEngine`: Flutter web (renders in the page, no WebView).
abstract interface class TurnstileEngine {
  /// Returns the widget hosting a visible Turnstile.
  ///
  /// The returned widget owns its session: it must call [onSessionCreated]
  /// when the bridge is ready and close the session when it is disposed.
  Widget buildView({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  });

  /// Starts an off-screen host and returns a handle to stop it.
  Future<TurnstileHeadlessHost> startHeadless({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
  });
}

/// Handle on an off-screen Turnstile host.
abstract interface class TurnstileHeadlessHost {
  /// Closes the session and frees the host. Idempotent.
  Future<void> dispose();
}
