import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() {
  group('TurnstileOptions', () {
    test('maps every field to the Turnstile render parameters', () {
      const options = TurnstileOptions(
        siteKey: 'key',
        action: 'login',
        cData: 'user_42',
        theme: TurnstileTheme.dark,
        size: TurnstileSize.compact,
        language: 'fr',
        appearance: TurnstileAppearance.interactionOnly,
        execution: TurnstileExecution.execute,
        retry: TurnstileRetry.never,
        retryInterval: Duration(seconds: 2),
        refreshExpired: TurnstileRefreshMode.manual,
        refreshTimeout: TurnstileRefreshMode.never,
        feedbackEnabled: false,
      );

      expect(options.toRenderParameters(), {
        'sitekey': 'key',
        'action': 'login',
        'cData': 'user_42',
        'theme': 'dark',
        'size': 'compact',
        'language': 'fr',
        'appearance': 'interaction-only',
        'execution': 'execute',
        'retry': 'never',
        'retry-interval': 2000,
        'refresh-expired': 'manual',
        'refresh-timeout': 'never',
        'feedback-enabled': false,
      });
    });

    test('omits optional action and cData', () {
      final params = const TurnstileOptions(siteKey: 'k').toRenderParameters();
      expect(params.containsKey('action'), isFalse);
      expect(params.containsKey('cData'), isFalse);
    });

    test('default configuration is valid', () {
      expect(const TurnstileOptions(siteKey: 'k').validate(), isEmpty);
    });

    test('reports invalid values', () {
      final options = TurnstileOptions(
        siteKey: ' ',
        action: 'a' * 33,
        cData: 'not valid!',
        language: 'french',
        retryInterval: const Duration(minutes: 20),
      );
      expect(options.validate(), hasLength(5));
      expect(options.ensureValid, throwsArgumentError);
    });

    test('supports value equality and copyWith', () {
      const a = TurnstileOptions(siteKey: 'k');
      final b = a.copyWith(theme: TurnstileTheme.light);
      expect(a, const TurnstileOptions(siteKey: 'k'));
      expect(a.hashCode, const TurnstileOptions(siteKey: 'k').hashCode);
      expect(b, isNot(a));
      expect(b.theme, TurnstileTheme.light);
      expect(b.siteKey, 'k');
    });

    test('exposes the preferred size of each widget size', () {
      expect(TurnstileSize.normal.preferredSize, const Size(300, 65));
      expect(TurnstileSize.compact.preferredSize, const Size(150, 140));
    });
  });
}
