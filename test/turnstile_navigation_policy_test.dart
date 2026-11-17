import 'package:flutter_test/flutter_test.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() {
  final policy = DefaultTurnstileNavigationPolicy(
    baseUri: Uri.parse('https://example.com'),
  );

  TurnstileNavigationDecision decide(String? url, {bool mainFrame = true}) =>
      policy.decide(
        uri: url == null ? null : Uri.parse(url),
        isMainFrame: mainFrame,
      );

  test('allows the host page and internal schemes', () {
    expect(decide('https://example.com/'), TurnstileNavigationDecision.allow);
    expect(decide('about:blank'), TurnstileNavigationDecision.allow);
    expect(decide('about:srcdoc'), TurnstileNavigationDecision.allow);
  });

  test('allows the Turnstile iframe', () {
    expect(
      decide('https://challenges.cloudflare.com/cdn-cgi/x', mainFrame: false),
      TurnstileNavigationDecision.allow,
    );
  });

  test('opens other main-frame links externally', () {
    expect(
      decide('https://www.cloudflare.com/privacypolicy/'),
      TurnstileNavigationDecision.openExternally,
    );
  });

  test('blocks unknown schemes and null URLs', () {
    expect(decide('intent://foo'), TurnstileNavigationDecision.block);
    expect(decide('javascript:alert(1)'), TurnstileNavigationDecision.block);
    expect(decide(null), TurnstileNavigationDecision.block);
  });
}
