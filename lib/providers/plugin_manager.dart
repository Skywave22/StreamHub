import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../core/errors/app_exception.dart';
import '../core/errors/error_messages.dart';
import '../core/platform/platform_info.dart';
import '../core/utils/versions.dart';
import 'external_provider.dart';
import 'plugin_installer.dart';
import 'provider.dart';
import 'provider_registry.dart';
import 'source_engine.dart';

class PluginLogEntry {
  PluginLogEntry(this.timestamp, this.level, this.message, {this.pluginId});
  final DateTime timestamp;
  final String level; // info | warn | error
  final String message;
  final String? pluginId;
}

/// Owns the full lifecycle of every provider/plugin: seed bundled providers,
/// install (URL / short code), enable, disable, update, reload, remove and
/// configure. Persists state in a Hive box and notifies the UI of changes.
class PluginManager extends ChangeNotifier {
  PluginManager({
    required ProviderRegistry registry,
    required Box<String> box,
    required PluginInstaller installer,
    required ProviderSourceEngine engine,
    int maxLogs = 200,
  })  : _registry = registry,
        _box = box,
        _installer = installer,
        _engine = engine,
        _maxLogs = maxLogs;

  final ProviderRegistry _registry;
  final Box<String> _box;
  final PluginInstaller _installer;
  final ProviderSourceEngine _engine;
  final int _maxLogs;

  final List<PluginLogEntry> _logs = [];
  List<InstalledPlugin> _cache = const [];

  List<PluginLogEntry> get logs => List.unmodifiable(_logs);

  void addLog(String level, String message, {String? pluginId}) {
    _logs.add(PluginLogEntry(DateTime.now(), level, message, pluginId: pluginId));
    if (_logs.length > _maxLogs) _logs.removeAt(0);
    notifyListeners();
  }

  /// Seeds bundled providers into storage (idempotent).
  Future<void> ensureSeeded() async {
    for (final provider in _registry.instantiateAll()) {
      final key = 'p:${provider.id}';
      if (!_box.containsKey(key)) {
        final record = InstalledPlugin(
          id: provider.id,
          name: provider.name,
          version: provider.version,
          description: provider.description,
          origin: PluginOrigin.bundled,
          platforms: provider.supportedPlatforms,
          capabilities: provider.capabilities,
          enabled: true,
          installedAt: DateTime.now(),
          permissions: const ['network'],
        );
        await _box.put(key, jsonEncode(record.toJson()));
      }
    }
    _reload();
  }

  void _reload() {
    _cache = _readAll();
    notifyListeners();
  }

  List<InstalledPlugin> _readAll() {
    final out = <InstalledPlugin>[];
    for (final key in _box.keys.map((k) => k.toString())) {
      if (!key.startsWith('p:')) continue;
      final raw = _box.get(key);
      if (raw == null) continue;
      try {
        out.add(InstalledPlugin.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // ignore corrupt records
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  List<InstalledPlugin> list() => List.unmodifiable(_cache);

  /// Providers supported on [platform] (unsupported ones are hidden).
  List<InstalledPlugin> visibleOn(AppPlatform platform) =>
      _cache.where((p) => p.isSupportedOn(platform)).toList();

  /// Enabled providers supported on [platform].
  List<InstalledPlugin> active(AppPlatform platform) =>
      _cache.where((p) => p.enabled && p.isSupportedOn(platform)).toList();

  InstalledPlugin? byId(String id) {
    for (final p in _cache) {
      if (p.id == id) return p;
    }
    return null;
  }

  StreamProvider? provider(String id) {
    final p = byId(id);
    if (p == null) return null;
    if (p.origin == PluginOrigin.bundled) {
      try {
        return _registry.create(id);
      } catch (_) {
        return null;
      }
    }
    return ExternalStreamProvider(record: p, engine: _engine);
  }

  List<StreamProvider> activeProviders(AppPlatform platform) {
    return active(platform).map((p) => provider(p.id)).whereType<StreamProvider>().toList();
  }

  // ---- Lifecycle -----------------------------------------------------------

  Future<void> setEnabled(String id, bool enabled) async {
    final p = byId(id);
    if (p == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    await _put(id, p.copyWith(
      enabled: enabled,
      status: enabled ? ProviderStatus.enabled : ProviderStatus.disabled,
      lastError: null,
    ));
    addLog('info', enabled ? 'Plugin enabled' : 'Plugin disabled', pluginId: id);
    _reload();
  }

  Future<void> remove(String id) async {
    final p = byId(id);
    if (p == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    await _box.delete('p:$id');
    addLog('info', 'Plugin removed', pluginId: id);
    _reload();
  }

  Future<void> configure(String id, Map<String, dynamic> config) async {
    final p = byId(id);
    if (p == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    final merged = {...p.config, ...config};
    await _put(id, p.copyWith(config: merged));
    addLog('info', 'Plugin configured', pluginId: id);
    _reload();
  }

  /// Re-fetches the plugin source and refreshes metadata/version.
  Future<void> reload(String id) async {
    final p = byId(id);
    if (p == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    if (p.sourceUrl == null) {
      await _put(id, p.copyWith(status: ProviderStatus.enabled, lastError: null));
      addLog('info', 'Plugin reloaded', pluginId: id);
      _reload();
      return;
    }
    await _put(id, p.copyWith(status: ProviderStatus.updating));
    _reload();
    try {
      final refreshed = await _refreshFromSource(p);
      await _put(id, refreshed);
      addLog('info', 'Plugin reloaded', pluginId: id);
    } on AppException catch (e) {
      await _put(id, p.copyWith(status: ProviderStatus.error, lastError: ErrorMessages.forException(e)));
      addLog('error', 'Reload failed: ${e.message}', pluginId: id);
    }
    _reload();
  }

  /// Updates the plugin from its source when a newer version is available.
  Future<bool> update(String id) async {
    final p = byId(id);
    if (p == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    if (p.sourceUrl == null) return false;
    await _put(id, p.copyWith(status: ProviderStatus.updating));
    _reload();
    try {
      final refreshed = await _refreshFromSource(p);
      await _put(id, refreshed);
      addLog('info', 'Plugin updated', pluginId: id);
      _reload();
      return true;
    } on AppException catch (e) {
      await _put(id, p.copyWith(status: ProviderStatus.error, lastError: ErrorMessages.forException(e)));
      _reload();
      return false;
    }
  }

  Future<InstalledPlugin> _refreshFromSource(InstalledPlugin p) async {
    final url = p.sourceUrl!;
    try {
      final repo = await _installer.fetchSkyStreamRepo(url);
      final newer = repo.manifestVersion > (p.config['manifestVersion'] as int? ?? 0);
      return p.copyWith(
        name: repo.name,
        version: newer ? '1.0.0' : p.version,
        description: repo.description,
        updatedAt: DateTime.now(),
        updateAvailable: newer ? 'repository updated (v${repo.manifestVersion})' : null,
        status: ProviderStatus.enabled,
        lastError: null,
        config: {...p.config, 'manifestVersion': repo.manifestVersion, 'pluginCount': repo.pluginCount},
      );
    } on AppException catch (e) {
      if (e.kind != AppErrorKind.manifestInvalid) rethrow;
    }
    final manifest = await _installer.fetchManifest(url);
    final newer = compareVersions(manifest.version, p.version) > 0;
    return p.copyWith(
      name: manifest.name,
      version: newer ? manifest.version : p.version,
      description: manifest.description,
      updatedAt: DateTime.now(),
      updateAvailable: newer ? manifest.version : null,
      status: ProviderStatus.enabled,
      lastError: null,
    );
  }

  /// Installs from a raw HTTPS plugin URL or a SkyStream short code.
  Future<InstallOutcome> install(String input, {AppPlatform? platform}) async {
    final outcome = await _installer.install(input, platform: platform);
    await _box.put('p:${outcome.plugin.id}', jsonEncode(outcome.plugin.toJson()));
    addLog('info', 'Installed plugin v${outcome.plugin.version}', pluginId: outcome.plugin.id);
    _reload();
    return outcome;
  }

  Future<void> _put(String id, InstalledPlugin record) async {
    await _box.put('p:$id', jsonEncode(record.toJson()));
  }
}
