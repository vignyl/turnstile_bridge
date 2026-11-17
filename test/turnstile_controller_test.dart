import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

import 'support/fakes.dart';

void main() {
  late TurnstileController controller;
  late FakeTurnstileSession session;

  setUp(() {
    controller = TurnstileController(loadTimeout: null);
    session = FakeTurnstileSession();
  });

  tearDown(() => controller.dispose());

  test('starts idle and becomes loading when attached', () {
    expect(controller.status, TurnstileStatus.idle);
    controller.attach(session);
    expect(controller.isAttached, isTrue);
    expect(controller.status, TurnstileStatus.loading);
  });

  test('tracks the lifecycle through events', () async {
    controller.attach(session);

    session.emit(const TurnstileLoaded(widgetId: 'w'));
    expect(controller.status, TurnstileStatus.ready);

    session.emit(const TurnstileInteractionRequired());
    expect(controller.status, TurnstileStatus.interactive);

    session.emit(const TurnstileInteractionCompleted());
    expect(controller.status, TurnstileStatus.ready);

    session.emit(const TurnstileTokenReceived('tok'));
    expect(controller.status, TurnstileStatus.verified);
    expect(controller.token, 'tok');

    session.emit(const TurnstileExpired());
    expect(controller.status, TurnstileStatus.expired);
    expect(controller.token, isNull);

    session.emit(TurnstileFailed(TurnstileError.fromCode('600010')));
    expect(controller.status, TurnstileStatus.failed);
    expect(controller.lastError?.code, '600010');

    session.emit(const TurnstileUnsupported());
    expect(controller.status, TurnstileStatus.unsupported);
  });

  test('forwards every event on the stream', () async {
    controller.attach(session);
    final received = <TurnstileEvent>[];
    final sub = controller.events.listen(received.add);

    session
      ..emit(const TurnstileLoaded())
      ..emit(const TurnstileResized(Size(300, 65)))
      ..emit(const TurnstileTokenReceived('t'));
    await pumpEventQueue();

    expect(received, const [
      TurnstileLoaded(),
      TurnstileResized(Size(300, 65)),
      TurnstileTokenReceived('t'),
    ]);
    await sub.cancel();
  });

  test('notifies listeners on state changes', () {
    controller.attach(session);
    var notifications = 0;
    controller.addListener(() => notifications++);
    session.emit(const TurnstileTokenReceived('t'));
    expect(notifications, 1);
  });

  test('sends commands to the session', () async {
    controller.attach(session);
    session.results[TurnstileCommand.getResponse] = 'tok';
    session.results[TurnstileCommand.isExpired] = true;

    await controller.reset();
    await controller.execute();
    await controller.remove();
    await controller.render();
    expect(await controller.getResponse(), 'tok');
    expect(await controller.isExpired(), isTrue);
    await controller.reload();

    expect(session.commands, [
      TurnstileCommand.reset,
      TurnstileCommand.execute,
      TurnstileCommand.remove,
      TurnstileCommand.render,
      TurnstileCommand.getResponse,
      TurnstileCommand.isExpired,
    ]);
    expect(session.reloads, 1);
  });

  test('reset clears the token and the last error', () async {
    controller.attach(session);
    session.emit(const TurnstileTokenReceived('t'));
    await controller.reset();
    expect(controller.token, isNull);
    expect(controller.lastError, isNull);
    expect(controller.status, TurnstileStatus.loading);
  });

  test('commands throw when not attached', () {
    expect(
      controller.reset(),
      throwsA(isA<TurnstileException>().having(
          (e) => e.error.code, 'code', TurnstileError.notAttachedCode)),
    );
  });

  test('refuses to drive two sessions at once', () {
    controller.attach(session);
    expect(() => controller.attach(FakeTurnstileSession()), throwsStateError);
  });

  test('detach releases the session and goes back to idle', () async {
    controller.attach(session);
    session.emit(const TurnstileTokenReceived('t'));
    controller.detach(session);
    expect(controller.isAttached, isFalse);
    expect(controller.status, TurnstileStatus.idle);
    expect(controller.token, isNull);
  });

  test('destroy tears the session down and recreate resets the status',
      () async {
    controller.attach(session);
    await controller.destroy();
    expect(session.destroyed, isTrue);
    expect(controller.isAttached, isFalse);
    expect(controller.status, TurnstileStatus.destroyed);

    controller.recreate();
    expect(controller.status, TurnstileStatus.idle);
  });

  group('waitForToken', () {
    test('returns the current token immediately', () async {
      controller.attach(session);
      session.emit(const TurnstileTokenReceived('now'));
      expect(await controller.waitForToken(), 'now');
    });

    test('completes with the next token', () async {
      controller.attach(session);
      final future = controller.waitForToken();
      session.emit(const TurnstileTokenReceived('next'));
      expect(await future, 'next');
    });

    test('throws on failure', () async {
      controller.attach(session);
      final future = controller.waitForToken();
      session.emit(TurnstileFailed(TurnstileError.fromCode('110200')));
      await expectLater(future, throwsA(isA<TurnstileException>()));
    });

    test('throws when interaction is required and not allowed', () async {
      controller.attach(session);
      final future = controller.waitForToken(failOnInteraction: true);
      session.emit(const TurnstileInteractionRequired());
      await expectLater(
        future,
        throwsA(isA<TurnstileException>().having((e) => e.error.code, 'code',
            TurnstileError.interactionRequiredCode)),
      );
    });

    test('throws after the timeout', () async {
      controller.attach(session);
      await expectLater(
        controller.waitForToken(timeout: const Duration(milliseconds: 10)),
        throwsA(isA<TurnstileException>().having(
            (e) => e.error.code, 'code', TurnstileError.tokenTimeoutCode)),
      );
    });
  });

  test('the watchdog reports a load timeout', () async {
    final guarded =
        TurnstileController(loadTimeout: const Duration(milliseconds: 10));
    guarded.attach(session);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(guarded.status, TurnstileStatus.failed);
    expect(guarded.lastError?.code, TurnstileError.loadTimeoutCode);
    guarded.dispose();
  });

  test('the watchdog is cancelled once the widget is rendered', () async {
    final guarded =
        TurnstileController(loadTimeout: const Duration(milliseconds: 10));
    guarded.attach(session);
    session.emit(const TurnstileLoaded());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(guarded.status, TurnstileStatus.ready);
    guarded.dispose();
  });

  test('dispose closes the stream and rejects further use', () async {
    final local = TurnstileController(loadTimeout: null)..attach(session);
    final done = expectLater(local.events, emitsDone);
    local.dispose();
    await done;
    expect(local.status, TurnstileStatus.disposed);
    expect(local.reset(), throwsA(isA<TurnstileException>()));
    expect(local.dispose, returnsNormally);
  });
}
