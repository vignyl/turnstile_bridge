import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

import 'support/fakes.dart';

void main() {
  final baseUrl = Uri.parse('https://example.com');
  const options = TurnstileOptions(siteKey: '1x00000000000000000000AA');

  late FakeTurnstileEngine engine;
  late TurnstileController controller;

  setUp(() {
    engine = FakeTurnstileEngine();
    controller = TurnstileController(loadTimeout: null);
  });

  tearDown(() => controller.dispose());

  Widget host({
    TurnstileOptions opts = options,
    TurnstileTokenCallback? onToken,
    TurnstileErrorCallback? onError,
    VoidCallback? onExpired,
    TurnstileEventCallback? onEvent,
    TurnstileController? ctrl,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: TurnstileWidget(
          engine: engine,
          controller: ctrl ?? controller,
          baseUrl: baseUrl,
          options: opts,
          resizeDuration: Duration.zero,
          onTokenReceived: onToken,
          onError: onError,
          onExpired: onExpired,
          onEvent: onEvent,
        ),
      ),
    );
  }

  Size hostSize(WidgetTester tester) =>
      tester.getSize(find.byType(KeyedSubtree).first);

  testWidgets('animates resizes by default without asserting',
      (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: TurnstileWidget(
          engine: engine,
          controller: controller,
          baseUrl: baseUrl,
          options: options,
        ),
      ),
    ));
    engine.last.emit(const TurnstileResized(Size(300, 140)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(hostSize(tester), const Size(300, 140));
    expect(find.byType(AnimatedSize), findsOneWidget);
  });

  testWidgets('attaches the controller and passes the configuration',
      (tester) async {
    await tester.pumpWidget(host());
    expect(engine.sessions, hasLength(1));
    expect(controller.isAttached, isTrue);
    expect(engine.configs.single.options, options);
    expect(engine.configs.single.baseUrl, baseUrl);
  });

  testWidgets('forwards events to the callbacks', (tester) async {
    String? token;
    TurnstileError? error;
    var expired = false;
    final events = <TurnstileEvent>[];

    await tester.pumpWidget(host(
      onToken: (t) => token = t,
      onError: (e) => error = e,
      onExpired: () => expired = true,
      onEvent: events.add,
    ));

    engine.last
      ..emit(const TurnstileTokenReceived('tok'))
      ..emit(TurnstileFailed(TurnstileError.fromCode('600010')))
      ..emit(const TurnstileExpired());
    await tester.pump();

    expect(token, 'tok');
    expect(error?.code, '600010');
    expect(expired, isTrue);
    expect(events, hasLength(3));
  });

  testWidgets('sizes itself from the preferred size, then from resize events',
      (tester) async {
    await tester.pumpWidget(host());
    expect(hostSize(tester), const Size(300, 65));

    engine.last.emit(const TurnstileResized(Size(300, 140)));
    await tester.pump(); // delivers the event (async stream) -> setState
    await tester.pump(); // lays out the new size
    expect(hostSize(tester), const Size(300, 140));
  });

  testWidgets('starts collapsed when the widget is hidden until needed',
      (tester) async {
    await tester.pumpWidget(host(
      opts: options.copyWith(appearance: TurnstileAppearance.interactionOnly),
    ));
    expect(hostSize(tester).height, 1);
  });

  testWidgets('destroy removes the host and recreate builds a new one',
      (tester) async {
    await tester.pumpWidget(host());
    final first = engine.last;

    await controller.destroy();
    await tester.pump();
    expect(first.destroyed, isTrue);
    expect(find.byType(KeyedSubtree), findsNothing);

    controller.recreate();
    await tester.pump();
    expect(engine.sessions, hasLength(2));
    expect(controller.isAttached, isTrue);
  });

  testWidgets('changing the options recreates the host', (tester) async {
    await tester.pumpWidget(host());
    final first = engine.last;

    await tester.pumpWidget(
      host(opts: options.copyWith(theme: TurnstileTheme.dark)),
    );
    expect(engine.sessions, hasLength(2));
    expect(first.closed, isTrue);
    expect(engine.last.closed, isFalse);
    expect(engine.configs.last.options.theme, TurnstileTheme.dark);
    expect(controller.isAttached, isTrue);
  });

  testWidgets('removing the widget closes the session and detaches',
      (tester) async {
    await tester.pumpWidget(host());
    final session = engine.last;

    await tester.pumpWidget(const SizedBox());
    expect(session.closed, isTrue);
    expect(controller.isAttached, isFalse);
  });

  testWidgets('switching controllers moves the session', (tester) async {
    final other = TurnstileController(loadTimeout: null);
    addTearDown(other.dispose);

    await tester.pumpWidget(host());
    await tester.pumpWidget(host(ctrl: other));

    expect(controller.isAttached, isFalse);
    expect(other.isAttached, isTrue);
    expect(engine.sessions, hasLength(1));
  });

  group('TurnstileHeadless', () {
    test('returns a token and frees the host', () async {
      final headless = TurnstileHeadless(
        engine: engine,
        baseUrl: baseUrl,
        options: options,
      );

      final future = headless.getToken();
      await pumpEventQueue();
      engine.last.emit(const TurnstileTokenReceived('invisible'));

      expect(await future, 'invisible');
      expect(headless.isRunning, isTrue);

      await headless.dispose();
      expect(engine.headlessDisposals, 1);
      expect(engine.last.closed, isTrue);
      expect(headless.controller.isDisposed, isTrue);
    });

    test('resets before issuing a second token', () async {
      final headless = TurnstileHeadless(
        engine: engine,
        baseUrl: baseUrl,
        options: options,
      );
      addTearDown(headless.dispose);

      final first = headless.getToken();
      await pumpEventQueue();
      engine.last.emit(const TurnstileTokenReceived('one'));
      expect(await first, 'one');

      final second = headless.getToken();
      await pumpEventQueue();
      expect(engine.last.commands, contains(TurnstileCommand.reset));
      engine.last.emit(const TurnstileTokenReceived('two'));
      expect(await second, 'two');
    });

    test('fails when an interaction is required', () async {
      final headless = TurnstileHeadless(
        engine: engine,
        baseUrl: baseUrl,
        options: options,
      );
      addTearDown(headless.dispose);

      final future = headless.getToken();
      await pumpEventQueue();
      engine.last.emit(const TurnstileInteractionRequired());

      await expectLater(
        future,
        throwsA(isA<TurnstileException>().having((e) => e.error.code, 'code',
            TurnstileError.interactionRequiredCode)),
      );
    });
  });
}
