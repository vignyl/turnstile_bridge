import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() {
  const decoder = JsonTurnstileMessageDecoder();

  group('JsonTurnstileMessageDecoder', () {
    test('decodes handler argument lists', () {
      expect(
        decoder.decode([
          {'type': 'token', 'token': 'abc'},
        ]),
        const TurnstileTokenReceived('abc'),
      );
    });

    test('decodes JSON strings', () {
      expect(decoder.decode('{"type":"expired"}'), const TurnstileExpired());
    });

    test('decodes every message type', () {
      expect(decoder.decode({'type': 'ready', 'widgetId': 'w1'}),
          const TurnstileLoaded(widgetId: 'w1'));
      expect(decoder.decode({'type': 'timeout'}), const TurnstileTimedOut());
      expect(decoder.decode({'type': 'beforeInteractive'}),
          const TurnstileInteractionRequired());
      expect(decoder.decode({'type': 'afterInteractive'}),
          const TurnstileInteractionCompleted());
      expect(
          decoder.decode({'type': 'unsupported'}), const TurnstileUnsupported());
      expect(decoder.decode({'type': 'resize', 'width': 300, 'height': 65}),
          const TurnstileResized(Size(300, 65)));
      expect(decoder.decode({'type': 'scriptError'}),
          const TurnstileFailed(TurnstileError.scriptLoadFailed()));
    });

    test('decodes errors with their category', () {
      final event = decoder.decode({'type': 'error', 'code': '110200'});
      expect(event, isA<TurnstileFailed>());
      final error = (event! as TurnstileFailed).error;
      expect(error.code, '110200');
      expect(error.category, TurnstileErrorCategory.invalidConfiguration);
    });

    test('ignores malformed or unknown messages', () {
      expect(decoder.decode(null), isNull);
      expect(decoder.decode(const <Object?>[]), isNull);
      expect(decoder.decode('not json'), isNull);
      expect(decoder.decode({'type': 'nope'}), isNull);
      expect(decoder.decode({'type': 'token', 'token': ''}), isNull);
      expect(decoder.decode({'type': 'resize', 'width': 'a'}), isNull);
    });
  });

  group('TurnstileCommand', () {
    test('scripts call the global bridge object defensively', () {
      expect(
        TurnstileCommand.reset.script,
        '(window.__turnstileBridge ? window.__turnstileBridge.reset() : null)',
      );
    });
  });
}
