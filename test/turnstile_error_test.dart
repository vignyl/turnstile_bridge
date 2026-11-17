import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() {
  group('TurnstileErrorClassifier', () {
    const classifier = TurnstileErrorClassifier();

    final cases = <String, TurnstileErrorCategory>{
      '100001': TurnstileErrorCategory.initialization,
      '105001': TurnstileErrorCategory.initialization,
      '102004': TurnstileErrorCategory.clientExecution,
      '110100': TurnstileErrorCategory.invalidConfiguration,
      '110200': TurnstileErrorCategory.invalidConfiguration,
      '110500': TurnstileErrorCategory.unsupportedEnvironment,
      '110510': TurnstileErrorCategory.unsupportedEnvironment,
      '110600': TurnstileErrorCategory.challengeTimeout,
      '110620': TurnstileErrorCategory.challengeTimeout,
      '200100': TurnstileErrorCategory.clockSkew,
      '300030': TurnstileErrorCategory.clientExecution,
      '600010': TurnstileErrorCategory.challengeFailed,
      'xyz': TurnstileErrorCategory.unknown,
    };

    cases.forEach((code, category) {
      test('classifies $code as ${category.name}', () {
        expect(classifier.classify(code), category);
      });
    });
  });

  group('TurnstileError', () {
    test('fromCode derives the category and retryability', () {
      final error = TurnstileError.fromCode('600010');
      expect(error.category, TurnstileErrorCategory.challengeFailed);
      expect(error.isRetryable, isTrue);
      expect(TurnstileError.fromCode('110200').isRetryable, isFalse);
    });

    test('local errors use stable codes', () {
      expect(const TurnstileError.loadTimeout().code, 'load_timeout');
      expect(const TurnstileError.notAttached().category,
          TurnstileErrorCategory.bridge);
    });

    test('TurnstileException exposes the error', () {
      const exception = TurnstileException(TurnstileError.disposed());
      expect(exception.error.code, TurnstileError.disposedCode);
      expect(exception.toString(), contains('disposed'));
    });
  });
}
