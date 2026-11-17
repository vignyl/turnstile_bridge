import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

/// In-memory [TurnstileSession] standing in for a WebView or web page.
class FakeTurnstileSession implements TurnstileSession {
  final StreamController<TurnstileEvent> _controller =
      StreamController<TurnstileEvent>.broadcast(sync: true);
  final List<TurnstileCommand> commands = [];
  final Map<TurnstileCommand, Object?> results = {};
  int reloads = 0;
  bool destroyed = false;
  bool closed = false;

  void emit(TurnstileEvent event) {
    if (!closed) _controller.add(event);
  }

  @override
  Stream<TurnstileEvent> get events => _controller.stream;

  @override
  Future<Object?> run(TurnstileCommand command) async {
    commands.add(command);
    return results[command];
  }

  @override
  Future<void> reload() async => reloads++;

  @override
  Future<void> destroy() async {
    destroyed = true;
    await close();
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await _controller.close();
  }
}

/// [TurnstileEngine] creating [FakeTurnstileSession]s, for widget tests.
class FakeTurnstileEngine implements TurnstileEngine {
  final List<FakeTurnstileSession> sessions = [];
  final List<TurnstileHostConfig> configs = [];
  int headlessDisposals = 0;

  FakeTurnstileSession get last => sessions.last;

  FakeTurnstileSession _newSession(TurnstileHostConfig config) {
    final session = FakeTurnstileSession();
    sessions.add(session);
    configs.add(config);
    return session;
  }

  @override
  Widget buildView({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  }) {
    return _FakeHost(
      create: () => _newSession(config),
      onSessionCreated: onSessionCreated,
    );
  }

  @override
  Future<TurnstileHeadlessHost> startHeadless({
    required TurnstileHostConfig config,
    required TurnstileSessionCallback onSessionCreated,
  }) async {
    final session = _newSession(config);
    onSessionCreated(session);
    return _FakeHeadlessHost(session, () => headlessDisposals++);
  }
}

class _FakeHeadlessHost implements TurnstileHeadlessHost {
  _FakeHeadlessHost(this._session, this._onDispose);

  final FakeTurnstileSession _session;
  final VoidCallback _onDispose;

  @override
  Future<void> dispose() async {
    _onDispose();
    await _session.close();
  }
}

class _FakeHost extends StatefulWidget {
  const _FakeHost({required this.create, required this.onSessionCreated});

  final FakeTurnstileSession Function() create;
  final TurnstileSessionCallback onSessionCreated;

  @override
  State<_FakeHost> createState() => _FakeHostState();
}

class _FakeHostState extends State<_FakeHost> {
  late final FakeTurnstileSession _session = widget.create();

  @override
  void initState() {
    super.initState();
    widget.onSessionCreated(_session);
  }

  @override
  void dispose() {
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
