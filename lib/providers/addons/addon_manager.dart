import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/errors/app_exception.dart';
import '../../core/networking/api_client.dart';
import '../provider.dart';
import 'addon_models.dart';
import 'addon_provider.dart';
import 'addon_service.dart';

/// Manages user-installed Nuvio/Stremio-compatible addons.
class AddonManager extends ChangeNotifier {
  AddonManager({required Box<String> box, required AddonService service, required ApiClient api})
      : _box = box,
        _service = service,
        _api = api {
    _reload();
  }

  final Box<String> _box;
  final AddonService _service;
  final ApiClient _api;

  List<ManagedAddon> _addons = const [];

  void _reload() {
    _addons = _box.values
        .whereType<String>()
        .map((s) {
          try {
            return ManagedAddon.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ManagedAddon>()
        .toList();
    notifyListeners();
  }

  List<ManagedAddon> get addons => List.unmodifiable(_addons);

  Future<ManagedAddon> addAddon(String url) async {
    final manifest = await _service.fetchManifest(url);
    final addon = ManagedAddon(manifestUrl: url.trim(), manifest: manifest, enabled: true);
    await _box.put(addon.manifestUrl, jsonEncode(addon.toJson()));
    _reload();
    return addon;
  }

  Future<void> removeAddon(String manifestUrl) async {
    await _box.delete(manifestUrl);
    _reload();
  }

  Future<void> setEnabled(String manifestUrl, bool enabled) async {
    final addon = _addons.where((a) => a.manifestUrl == manifestUrl).firstOrNull;
    if (addon == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Addon not found.');
    await _box.put(manifestUrl, jsonEncode(addon.copyWith(enabled: enabled).toJson()));
    _reload();
  }

  List<StreamProvider> enabledProviders() {
    return _addons
        .where((a) => a.enabled)
        .map((a) => AddonProvider(addon: a, service: _service, api: _api))
        .toList();
  }
}
