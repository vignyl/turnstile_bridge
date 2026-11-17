import 'dart:convert';

import '../bridge/turnstile_js_api.dart';
import '../core/turnstile_options.dart';

/// Produces the HTML page hosting the Turnstile widget.
abstract interface class TurnstileDocumentBuilder {
  /// Returns a full HTML document for [options].
  String build(TurnstileOptions options);
}

/// Default document: a transparent page that loads `api.js`, renders the
/// widget explicitly and wires every Turnstile callback to the Dart bridge.
class TurnstileHtmlDocumentBuilder implements TurnstileDocumentBuilder {
  /// Creates the builder. [scriptUrl] can point to a proxy or a mirror.
  const TurnstileHtmlDocumentBuilder({this.scriptUrl = defaultScriptUrl});

  /// Official Turnstile script URL.
  static const String defaultScriptUrl =
      'https://challenges.cloudflare.com/turnstile/v0/api.js';

  /// URL of the Turnstile script, without query string.
  final String scriptUrl;

  @override
  String build(TurnstileOptions options) {
    options.ensureValid();
    const attribute = HtmlEscape(HtmlEscapeMode.attribute);
    final lang = options.language == 'auto' ? '' : ' lang="${options.language}"';
    final display =
        options.size == TurnstileSize.flexible ? 'block' : 'inline-block';

    return _template
        .replaceAll('{{LANG}}', lang)
        .replaceAll('{{DISPLAY}}', display)
        .replaceAll('{{CONTAINER}}', TurnstileJsApi.containerId)
        .replaceAll('{{HANDLER}}', TurnstileJsApi.handlerName)
        .replaceAll('{{GLOBAL}}', TurnstileJsApi.globalObject)
        .replaceAll('{{SCRIPT_URL}}', attribute.convert(scriptUrl))
        // Last, so that user-provided values cannot inject placeholders.
        .replaceAll('{{PARAMS}}', _jsonForScript(options.toRenderParameters()));
  }

  /// Characters that must not appear verbatim inside an inline `<script>`:
  /// `<`, `>`, `&`, LINE SEPARATOR (U+2028) and PARAGRAPH SEPARATOR (U+2029).
  static final RegExp _unsafeForScript = RegExp(
    '[<>&${String.fromCharCode(0x2028)}${String.fromCharCode(0x2029)}]',
  );

  /// JSON safe to inline in a `<script>` element: unsafe characters are
  /// replaced by their JavaScript unicode escape sequence.
  static String _jsonForScript(Object value) =>
      jsonEncode(value).replaceAllMapped(_unsafeForScript, (match) {
        final hex = match[0]!.codeUnitAt(0).toRadixString(16).padLeft(4, '0');
        return '${r'\'}u$hex';
      });

  static const String _template = r'''<!DOCTYPE html>
<html{{LANG}}>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
  #{{CONTAINER}} { display: {{DISPLAY}}; }
</style>
<script>
(function () {
  'use strict';
  var params = {{PARAMS}};
  var handler = '{{HANDLER}}';
  var selector = '#{{CONTAINER}}';
  var widgetId = null;
  var rendered = false;
  var queue = [];
  var lastSize = null;

  function bridgeAvailable() {
    return !!(window.flutter_inappwebview && window.flutter_inappwebview.callHandler);
  }
  function flush() {
    while (queue.length && bridgeAvailable()) {
      window.flutter_inappwebview.callHandler(handler, queue.shift());
    }
  }
  function post(message) { queue.push(message); flush(); }
  window.addEventListener('flutterInAppWebViewPlatformReady', flush);

  function apiLoaded() { return typeof window.turnstile !== 'undefined'; }
  function hasWidget() { return widgetId !== null && apiLoaded(); }

  function reportSize() {
    // Skip the empty container before the first render and hidden layouts:
    // both would report a misleading 0x0.
    if (!rendered) { return; }
    var el = document.getElementById('{{CONTAINER}}');
    if (!el || el.getClientRects().length === 0) { return; }
    var rect = el.getBoundingClientRect();
    var w = Math.ceil(rect.width), h = Math.ceil(rect.height);
    // Turnstile inserts its iframe asynchronously: ignore empty sizes until a
    // real one has been seen. Later zero heights (remove, interaction-only)
    // are meaningful and reported.
    if (!lastSize && (w === 0 || h === 0)) { return; }
    if (lastSize && lastSize.w === w && lastSize.h === h) { return; }
    lastSize = { w: w, h: h };
    post({ type: 'resize', width: w, height: h });
  }
  function observeSize() {
    var el = document.getElementById('{{CONTAINER}}');
    if (!el) { return; }
    if (window.ResizeObserver) { new window.ResizeObserver(reportSize).observe(el); }
    else { window.setInterval(reportSize, 500); }
    reportSize();
  }

  function render() {
    if (!apiLoaded()) { return null; }
    if (widgetId !== null) { return widgetId; }
    var options = Object.assign({}, params, {
      'callback': function (token) { post({ type: 'token', token: token }); },
      'error-callback': function (code) { post({ type: 'error', code: String(code) }); return true; },
      'expired-callback': function () { post({ type: 'expired' }); },
      'timeout-callback': function () { post({ type: 'timeout' }); },
      'before-interactive-callback': function () { post({ type: 'beforeInteractive' }); },
      'after-interactive-callback': function () { post({ type: 'afterInteractive' }); },
      'unsupported-callback': function () { post({ type: 'unsupported' }); }
    });
    try {
      var id = window.turnstile.render(selector, options);
      widgetId = (id === undefined || id === null) ? null : id;
      if (widgetId !== null) {
        rendered = true;
        post({ type: 'ready', widgetId: String(widgetId) });
        reportSize();
      }
    } catch (e) {
      post({ type: 'error', code: 'render_failed', message: String((e && e.message) || e) });
    }
    return widgetId;
  }
  function reset() {
    if (hasWidget()) { window.turnstile.reset(widgetId); return true; }
    return render() !== null;
  }
  function remove() {
    if (hasWidget()) { window.turnstile.remove(widgetId); }
    widgetId = null;
    reportSize();
    return true;
  }
  function execute() {
    if (!apiLoaded()) { return false; }
    if (widgetId === null) { render(); }
    if (widgetId === null) { return false; }
    window.turnstile.execute(selector);
    return true;
  }
  function getResponse() { return hasWidget() ? (window.turnstile.getResponse(widgetId) || null) : null; }
  function isExpired() { return hasWidget() ? !!window.turnstile.isExpired(widgetId) : false; }

  window['{{GLOBAL}}'] = {
    render: render, reset: reset, remove: remove, execute: execute,
    getResponse: getResponse, isExpired: isExpired
  };

  function whenDomReady(fn) {
    if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', fn); }
    else { fn(); }
  }
  window.__onTurnstileLoaded = function () { whenDomReady(render); };
  window.__onTurnstileScriptError = function () { post({ type: 'scriptError' }); };
  whenDomReady(observeSize);
})();
</script>
<script src="{{SCRIPT_URL}}?render=explicit&amp;onload=__onTurnstileLoaded" async defer onerror="__onTurnstileScriptError()"></script>
</head>
<body><div id="{{CONTAINER}}"></div></body>
</html>
''';
}
