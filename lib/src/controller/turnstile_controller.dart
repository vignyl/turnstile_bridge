import 'dart:async';

import 'package:flutter/foundation.dart';
// Needed for `@internal` on Flutter versions whose foundation library does not
// re-export it yet.
// ignore: unnecessary_import
import 'package:meta/meta.dart';

import '../bridge/turnstile_command.dart';
import '../bridge/turnstile_session.dart';
import '../core/turnstile_error.dart';
import '../core/turnstile_event.dart';
import '../core/turnstile_status.dart';

/// Drives a Turnstile widget and exposes its state.
///
/// * Listen to [events] for every JavaScript callback, or use the
///   [ChangeNotifier] API ([status], [token], [lastError]) to rebuild UI.
/// * Call [reset], [remove], [render], [execute], [reload] or [destroy] to
///   control the widget.
/// * Call [dispose] when you created the controller yourself.
///
/// The controller only knows the [TurnstileSession] abstraction; it is
/// attached by `TurnstileWidget` or `TurnstileHeadless`.
class TurnstileController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// [loadTimeout] is the maximum time between loading and the widget being
  /// rendered before a [TurnstileError.loadTimeout] is reported. `null`
  /// disables the watchdog.
  TurnstileController({this.loadTimeout = const Duration(seconds: 30)});

  /// Maximum time allowed for Turnstile to render.
  final Duration? loadTimeout;

  final StreamController<TurnstileEvent> _events =
      StreamController<TurnstileEvent>.broadcast();
  TurnstileSession? _session;
  StreamSubscription<TurnstileEvent>? _subscription;
  Timer? _watchdog;
  TurnstileStatus _status = TurnstileStatus.idle;
  String? _token;
  TurnstileError? _lastError;
  bool _disposed = false;

  /// Broadcast stream of every event coming from Turnstile.
  Stream<TurnstileEvent> get events => _events.stream;

  /// Current lifecycle state.
  TurnstileStatus get status => _status;

  /// Latest valid token, or `null`.
  String? get token => _token;

  /// Whether [token] is available.
  bool get hasToken => _token != null;

  /// Latest error, cleared when a token is received or on [reset].
  TurnstileError? get lastError => _lastError;

  /// Whether a WebView is currently attached.
  bool get isAttached => _session != null;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  // ---------------------------------------------------------------------------
  // Binding (used by TurnstileWidget / TurnstileHeadless).
  // ---------------------------------------------------------------------------

  /// Attaches [session]. A controller drives one WebView at a time.
  @internal
  void attach(TurnstileSession session) {
    _ensureNotDisposed();
    if (identical(_session, session)) return;
    if (_session != null) {
      throw StateError(
        'This TurnstileController is already attached to another widget. '
        'Use one controller per TurnstileWidget.',
      );
    }
    _session = session;
    _subscription = session.events.listen(_handle);
    _token = null;
    _lastError = null;
    _status = TurnstileStatus.loading;
    _armWatchdog();
    _notifyLater();
  }

  /// Detaches [session] if it is the attached one.
  @internal
  void detach(TurnstileSession session) {
    if (!identical(_session, session)) return;
    _release();
    if (_disposed) return;
    _token = null;
    if (_status != TurnstileStatus.destroyed) _status = TurnstileStatus.idle;
    _notifyLater();
  }

  // ---------------------------------------------------------------------------
  // Commands.
  // ---------------------------------------------------------------------------

  /// Discards the current token and starts a new challenge.
  Future<void> reset() async {
    final session = _requireSession();
    _token = null;
    _lastError = null;
    _update(TurnstileStatus.loading);
    _armWatchdog();
    await session.run(TurnstileCommand.reset);
  }

  /// Removes the widget from the page, keeping the WebView alive.
  Future<void> remove() async {
    final session = _requireSession();
    _cancelWatchdog();
    await session.run(TurnstileCommand.remove);
    _token = null;
    _update(TurnstileStatus.idle);
  }

  /// Renders the widget again after [remove].
  Future<void> render() async {
    final session = _requireSession();
    _update(TurnstileStatus.loading);
    _armWatchdog();
    await session.run(TurnstileCommand.render);
  }

  /// Runs the challenge when `TurnstileExecution.execute` is used.
  Future<void> execute() async {
    await _requireSession().run(TurnstileCommand.execute);
  }

  /// Reloads the whole page (new script, new widget).
  Future<void> reload() async {
    final session = _requireSession();
    _token = null;
    _lastError = null;
    _update(TurnstileStatus.loading);
    _armWatchdog();
    await session.reload();
  }

  /// Reads the current token from the page.
  Future<String?> getResponse() async {
    final result = await _requireSession().run(TurnstileCommand.getResponse);
    return result is String && result.isNotEmpty ? result : null;
  }

  /// Asks the page whether the current token is expired.
  Future<bool> isExpired() async {
    final result = await _requireSession().run(TurnstileCommand.isExpired);
    return result == true;
  }

  /// Removes the widget, unloads the page and frees the WebView.
  ///
  /// The hosting `TurnstileWidget` then renders nothing until [recreate] is
  /// called. Typical use: free resources once the token has been consumed.
  Future<void> destroy() async {
    _ensureNotDisposed();
    final session = _session;
    _release();
    if (session != null) await session.destroy();
    if (_disposed) return;
    _token = null;
    _update(TurnstileStatus.destroyed);
  }

  /// Asks the hosting `TurnstileWidget` to create a new WebView after
  /// [destroy].
  void recreate() {
    _ensureNotDisposed();
    if (_status == TurnstileStatus.destroyed) _update(TurnstileStatus.idle);
  }

  /// Completes with the next token (or the current one if available).
  ///
  /// Throws a [TurnstileException] on failure, when Turnstile is unsupported,
  /// after [timeout], when the controller is disposed, or, if
  /// [failOnInteraction] is true, when an interactive challenge is required.
  Future<String> waitForToken({
    Duration timeout = const Duration(minutes: 2),
    bool failOnInteraction = false,
  }) async {
    _ensureNotDisposed();
    final current = _token;
    if (current != null) return current;
    try {
      final event = await events
          .firstWhere(
            (e) =>
                e is TurnstileTokenReceived ||
                e is TurnstileFailed ||
                e is TurnstileUnsupported ||
                (failOnInteraction && e is TurnstileInteractionRequired),
          )
          .timeout(timeout);
      return switch (event) {
        TurnstileTokenReceived(:final token) => token,
        TurnstileFailed(:final error) => throw TurnstileException(error),
        TurnstileInteractionRequired() =>
          throw const TurnstileException(TurnstileError.interactionRequired()),
        _ => throw const TurnstileException(TurnstileError.unsupported()),
      };
    } on TimeoutException {
      throw const TurnstileException(TurnstileError.tokenTimeout());
    } on StateError {
      // The event stream closed before an answer: the controller was disposed.
      throw const TurnstileException(TurnstileError.disposed());
    }
  }

  /// Detaches from the WebView and closes [events]. The WebView itself is
  /// owned and freed by the widget.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _release();
    _token = null;
    _status = TurnstileStatus.disposed;
    unawaited(_events.close());
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internals.
  // ---------------------------------------------------------------------------

  void _handle(TurnstileEvent event) {
    if (_disposed) return;
    switch (event) {
      case TurnstileLoaded():
        _cancelWatchdog();
        _update(TurnstileStatus.ready);
      case TurnstileTokenReceived(:final token):
        _cancelWatchdog();
        _token = token;
        _lastError = null;
        _update(TurnstileStatus.verified);
      case TurnstileFailed(:final error):
        _cancelWatchdog();
        _token = null;
        _lastError = error;
        _update(TurnstileStatus.failed);
      case TurnstileExpired():
        _token = null;
        _update(TurnstileStatus.expired);
      case TurnstileTimedOut():
        _token = null;
        _update(TurnstileStatus.timedOut);
      case TurnstileInteractionRequired():
        _cancelWatchdog();
        _update(TurnstileStatus.interactive);
      case TurnstileInteractionCompleted():
        if (_status == TurnstileStatus.interactive) {
          _update(TurnstileStatus.ready);
        }
      case TurnstileUnsupported():
        _cancelWatchdog();
        _token = null;
        _lastError = const TurnstileError.unsupported();
        _update(TurnstileStatus.unsupported);
      case TurnstileResized():
        break;
    }
    _events.add(event);
  }

  void _armWatchdog() {
    _cancelWatchdog();
    final timeout = loadTimeout;
    if (timeout == null) return;
    _watchdog = Timer(timeout, () {
      _watchdog = null;
      if (_session != null) {
        _handle(const TurnstileFailed(TurnstileError.loadTimeout()));
      }
    });
  }

  void _cancelWatchdog() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  void _release() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _session = null;
    _cancelWatchdog();
  }

  void _update(TurnstileStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Notifies after the current frame work, so that attach / detach called
  /// from widget lifecycle methods never trigger `setState` during build.
  void _notifyLater() {
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  TurnstileSession _requireSession() {
    _ensureNotDisposed();
    final session = _session;
    if (session == null) {
      throw const TurnstileException(TurnstileError.notAttached());
    }
    return session;
  }

  void _ensureNotDisposed() {
    if (_disposed) throw const TurnstileException(TurnstileError.disposed());
  }
}
