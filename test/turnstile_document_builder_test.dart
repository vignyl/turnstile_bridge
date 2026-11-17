import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() {
  const builder = TurnstileHtmlDocumentBuilder();

  group('TurnstileHtmlDocumentBuilder', () {
    test('embeds the site key, the bridge names and the official script', () {
      final html = builder.build(const TurnstileOptions(siteKey: '1x00000000000000000000AA'));

      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('"sitekey":"1x00000000000000000000AA"'));
      expect(html, contains("var handler = '${TurnstileJsApi.handlerName}'"));
      expect(html, contains("window['${TurnstileJsApi.globalObject}']"));
      expect(html, contains('id="${TurnstileJsApi.containerId}"'));
      expect(
        html,
        contains('${TurnstileHtmlDocumentBuilder.defaultScriptUrl}'
            '?render=explicit&amp;onload=__onTurnstileLoaded'),
      );
      expect(html, isNot(contains('{{')));
    });

    test('wires every Turnstile callback', () {
      final html = builder.build(const TurnstileOptions(siteKey: 'k'));
      for (final callback in [
        "'callback'",
        "'error-callback'",
        "'expired-callback'",
        "'timeout-callback'",
        "'before-interactive-callback'",
        "'after-interactive-callback'",
        "'unsupported-callback'",
      ]) {
        expect(html, contains(callback));
      }
    });

    test('escapes values so they cannot close the script element', () {
      // Bypass validation on purpose to prove the escaping layer.
      final html = const _UnsafeBuilder().build(
        const TurnstileOptions(siteKey: '</script><script>alert(1)</script>'),
      );
      expect(html, isNot(contains('</script><script>alert(1)')));
      const backslash = r'\';
      expect(html, contains('${backslash}u003c/script${backslash}u003e'));
    });

    test('sets the lang attribute and the flexible layout', () {
      final html = builder.build(const TurnstileOptions(
        siteKey: 'k',
        language: 'fr',
        size: TurnstileSize.flexible,
      ));
      expect(html, contains('<html lang="fr">'));
      expect(html, contains('display: block;'));
    });

    test('rejects invalid options', () {
      expect(
        () => builder.build(const TurnstileOptions(siteKey: '')),
        throwsArgumentError,
      );
    });
  });
}

/// Same template, without validation, to test escaping in isolation.
class _UnsafeBuilder extends TurnstileHtmlDocumentBuilder {
  const _UnsafeBuilder();

  @override
  String build(TurnstileOptions options) =>
      super.build(_ValidOptions(options));
}

class _ValidOptions extends TurnstileOptions {
  _ValidOptions(TurnstileOptions source) : super(siteKey: source.siteKey);

  @override
  void ensureValid() {}
}
