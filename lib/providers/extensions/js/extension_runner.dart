import 'dart:convert';

import 'package:flutter_js/flutter_js.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../../core/errors/app_exception.dart';
import 'sdk_shim.dart';

/// Runs an installed extension's JavaScript and invokes its exported entry
/// points. Abstract so tests can use a fake; the production implementation is
/// backed by QuickJS (via `flutter_js`).
abstract class ExtensionRunner {
  Future<void> init();

  /// Invokes a global JS function by name (e.g. `search`, `loadStreams`) with
  /// the given JSON-serialisable arguments; the extension's callback result is
  /// awaited and returned decoded.
  Future<dynamic> invoke(String fnName, [List<dynamic>? args]);

  void dispose();
}

/// QuickJS-backed runner using the `flutter_js` runtime. A synchronous Dart
/// bridge (`sendMessage`) serves DOM parsing/querying and preferences/storage.
class QuickJsExtensionRunner implements ExtensionRunner {
  QuickJsExtensionRunner({
    required this.script,
    required this.manifestJson,
    this.storage,
    this.prefs,
  });

  final String script;
  final String manifestJson;
  final Map<String, String>? storage;
  final Map<String, String>? prefs;

  JavascriptRuntime? _runtime;
  final Map<int, dynamic> _dom = {};
  int _domSeq = 0;
  bool _inited = false;

  @override
  Future<void> init() async {
    if (_inited) return;
    final runtime = getJavascriptRuntime();
    _runtime = runtime;
    runtime.onMessage('streamhub', _bridge);
    await runtime.evaluateAsync(SdkShim.source(manifestJson: manifestJson));
    await runtime.evaluateAsync(script);
    _inited = true;
  }

  // ---- synchronous Dart bridge --------------------------------------------

  dynamic _bridge(dynamic args) {
    if (args is! Map) return null;
    final method = args['method'] as String?;
    final params = (args['params'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    switch (method) {
      case 'dom_parse':
        return _domParse(params['html'] as String? ?? '');
      case 'dom_query':
        return _domQuery(
          (params['nodeId'] as num?)?.toInt() ?? 0,
          params['query'] as String? ?? '',
          params['multi'] == true,
        );
      case 'get_preference': {
        final key = params['key'] as String?;
        return key == null ? null : prefs?[key];
      }
      case 'set_preference': {
        final key = params['key'] as String?;
        final value = params['value'];
        if (key != null && value != null) prefs?[key] = value.toString();
        return null;
      }
      case 'get_storage': {
        final key = params['key'] as String?;
        return key == null ? null : storage?[key];
      }
      case 'set_storage': {
        final key = params['key'] as String?;
        final value = params['value'];
        if (key != null && value != null) storage?[key] = value.toString();
        return null;
      }
      case 'solve_captcha':
        return null;
      default:
        return null;
    }
  }

  int _domParse(String html) {
    final Document doc = html_parser.parse(html);
    final id = ++_domSeq;
    _dom[id] = doc;
    return id;
  }

  dynamic _domQuery(int nodeId, String query, bool multi) {
    final dynamic node = _dom[nodeId];
    if (node == null) return multi ? const <dynamic>[] : null;
    try {
      if (multi) {
        final List<Element> els = (node.querySelectorAll(query) as List<Element>);
        return els.map(_nodeData).toList();
      }
      final el = node.querySelector(query) as Element?;
      return el == null ? null : _nodeData(el);
    } catch (_) {
      return multi ? const <dynamic>[] : null;
    }
  }

  Map<String, dynamic> _nodeData(Element el) {
    final id = ++_domSeq;
    _dom[id] = el;
    return {
      'nodeId': id,
      'tagName': el.localName ?? '',
      'textContent': el.text,
      'innerHTML': el.innerHtml,
      'outerHTML': el.outerHtml,
      'attributes': Map<String, String>.from(el.attributes),
    };
  }

  // ---- invocation ---------------------------------------------------------

  @override
  Future<dynamic> invoke(String fnName, [List<dynamic>? args]) async {
    await init();
    final runtime = _runtime!;
    final encoded = (args ?? const <dynamic>[])
        .map((a) => jsonEncode(a))
        .toList();
    encoded.add('function (r) { resolve(r); }');
    final callArgs = encoded.join(', ');
    final call = '''
(function(){ return new Promise(function (resolve, reject) {
  try {
    var f = (typeof $fnName === 'function') ? $fnName : globalThis.$fnName;
    if (typeof f !== 'function') { reject('function "$fnName" not found'); return; }
    var r = f($callArgs);
    if (r && typeof r.then === 'function') { r.then(resolve, reject); }
  } catch (e) { reject(String(e && e.message ? e.message : e)); }
}); })()
''';
    final result = runtime.evaluate(call);
    final handled = await runtime.handlePromise(result, timeout: const Duration(seconds: 60));
    final s = handled.stringResult;    if (s.isEmpty || s == 'null' || s == 'undefined') return null;
    return jsonDecode(s);
  }

  @override
  void dispose() {
    _runtime?.dispose();
    _runtime = null;
    _inited = false;
    _dom.clear();
  }
}

/// Maps a caught runner failure to a friendly AppException.
AppException runnerError(Object e) {
  final msg = e.toString();
  if (msg.contains('not found')) {
    return const AppException(AppErrorKind.providerUnavailable, message: 'This plugin does not support that feature.');
  }
  return const AppException(AppErrorKind.providerUnavailable, message: 'The plugin failed while running.\nTry reloading it.');
}
