// Kept for compatibility with Flutter versions older than 3.47, where
// material_ui does not exist yet.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:turnstile_bridge/turnstile_bridge.dart';

void main() => runApp(const TurnstileExampleApp());

/// Cloudflare test site keys: they work on any hostname.
/// https://developers.cloudflare.com/turnstile/troubleshooting/testing/
enum TestSiteKey {
  passes('Always passes', '1x00000000000000000000AA'),
  blocks('Always blocks', '2x00000000000000000000AB'),
  interactive('Forces interaction', '3x00000000000000000000FF');

  const TestSiteKey(this.label, this.value);

  final String label;
  final String value;
}

/// Invisible test key used by the headless demo.
const String invisibleTestSiteKey = '1x00000000000000000000BB';

/// With real keys, use a hostname allowed for the key in the dashboard.
final Uri baseUrl = Uri.parse('https://example.com');

/// Shortens a token for display. Test tokens are only 21 characters long.
String _preview(String token) =>
    token.length <= 32 ? token : '${token.substring(0, 32)}...';

class TurnstileExampleApp extends StatelessWidget {
  const TurnstileExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Turnstile Bridge',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final TurnstileController _controller = TurnstileController();
  final List<String> _log = [];
  TestSiteKey _siteKey = TestSiteKey.passes;
  TurnstileTheme _theme = TurnstileTheme.auto;
  TurnstileSize _size = TurnstileSize.normal;
  String? _headlessResult;
  bool _headlessRunning = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addLog(String line) {
    setState(() {
      _log.insert(0, '${TimeOfDay.now().format(context)}  $line');
      if (_log.length > 50) _log.removeLast();
    });
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on TurnstileException catch (e) {
      _addLog('Exception: ${e.error}');
    }
  }

  Future<void> _runHeadless() async {
    setState(() {
      _headlessRunning = true;
      _headlessResult = null;
    });
    final headless = TurnstileHeadless(
      baseUrl: baseUrl,
      options: const TurnstileOptions(siteKey: invisibleTestSiteKey),
    );
    try {
      final token = await headless.getToken();
      _headlessResult = 'Token: ${_preview(token)}';
    } on TurnstileException catch (e) {
      _headlessResult = 'Failed: ${e.error}';
    } finally {
      await headless.dispose();
      if (mounted) setState(() => _headlessRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = TurnstileOptions(
      siteKey: _siteKey.value,
      theme: _theme,
      size: _size,
      action: 'example',
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Turnstile Bridge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConfigurationCard(
            siteKey: _siteKey,
            theme: _theme,
            size: _size,
            onSiteKeyChanged: (v) => setState(() => _siteKey = v),
            onThemeChanged: (v) => setState(() => _theme = v),
            onSizeChanged: (v) => setState(() => _size = v),
          ),
          const SizedBox(height: 16),
          Center(
            child: TurnstileWidget(
              controller: _controller,
              baseUrl: baseUrl,
              options: options,
              onEvent: (event) => _addLog(event.toString()),
              onTokenReceived: (token) =>
                  _addLog('Send this token to your backend for siteverify.'),
              onError: (error) => _addLog(
                error.isRetryable ? 'Retryable error.' : 'Fatal error.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _StatusCard(controller: _controller),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _guard(_controller.reset),
                child: const Text('Reset'),
              ),
              FilledButton.tonal(
                onPressed: () => _guard(_controller.remove),
                child: const Text('Remove'),
              ),
              FilledButton.tonal(
                onPressed: () => _guard(_controller.render),
                child: const Text('Render'),
              ),
              FilledButton.tonal(
                onPressed: () => _guard(() async {
                  _addLog('getResponse: ${await _controller.getResponse()}');
                }),
                child: const Text('getResponse'),
              ),
              FilledButton.tonal(
                onPressed: () => _guard(_controller.destroy),
                child: const Text('Destroy WebView'),
              ),
              FilledButton.tonal(
                onPressed: () => _guard(() async => _controller.recreate()),
                child: const Text('Recreate'),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Headless (invisible key)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _headlessRunning ? null : _runHeadless,
                child: const Text('Get invisible token'),
              ),
              const SizedBox(width: 12),
              if (_headlessRunning)
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              if (_headlessResult != null)
                Expanded(child: Text(_headlessResult!)),
            ],
          ),
          const Divider(height: 32),
          Text('Events', style: Theme.of(context).textTheme.titleMedium),
          for (final line in _log)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(line, style: const TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _ConfigurationCard extends StatelessWidget {
  const _ConfigurationCard({
    required this.siteKey,
    required this.theme,
    required this.size,
    required this.onSiteKeyChanged,
    required this.onThemeChanged,
    required this.onSizeChanged,
  });

  final TestSiteKey siteKey;
  final TurnstileTheme theme;
  final TurnstileSize size;
  final ValueChanged<TestSiteKey> onSiteKeyChanged;
  final ValueChanged<TurnstileTheme> onThemeChanged;
  final ValueChanged<TurnstileSize> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _dropdown<TestSiteKey>('Test key', siteKey, TestSiteKey.values,
                (v) => v.label, onSiteKeyChanged),
            _dropdown<TurnstileTheme>('Theme', theme, TurnstileTheme.values,
                (v) => v.name, onThemeChanged),
            _dropdown<TurnstileSize>('Size', size, TurnstileSize.values,
                (v) => v.name, onSizeChanged),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> values,
    String Function(T) describe,
    ValueChanged<T> onChanged,
  ) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label)),
        Expanded(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            items: [
              for (final v in values)
                DropdownMenuItem(value: v, child: Text(describe(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final TurnstileController controller;

  @override
  Widget build(BuildContext context) {
    final token = controller.token;
    return Card(
      child: ListTile(
        title: Text('Status: ${controller.status.name}'),
        subtitle: Text(
          token != null
              ? 'Token: ${_preview(token)}'
              : controller.lastError?.toString() ?? 'No token yet',
        ),
      ),
    );
  }
}
