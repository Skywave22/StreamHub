import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../core/errors/app_exception.dart';
import '../../core/networking/api_client.dart';
import '../provider.dart';
import 'extension_models.dart';
import 'js/extension_runner.dart';
import 'js_extension_provider.dart';
import 'repository_service.dart';

/// Manages SkyStream/CloudStream repositories and installed JS extensions:
/// install, enable, disable, update, uninstall and run. State is persisted in
/// Hive; extensions are run in QuickJS and are the real streaming providers.
class ExtensionManager extends ChangeNotifier {
  ExtensionManager({
    required Box<String> repoBox,
    required Box<String> pluginBox,
    required Box<String> dataBox,
    required this.repositoryService,
    required ApiClient api,
  })  : _repoBox = repoBox,
        _pluginBox = pluginBox,
        _dataBox = dataBox,
        _api = api {
    _loadData();
  }

  final Box<String> _repoBox;
  final Box<String> _pluginBox;
  final Box<String> _dataBox;
  final RepositoryService repositoryService;
  final ApiClient _api;

  final Map<String, String> _data = {};

  List<ExtensionRepository> _repos = const [];
  List<InstalledExtension> _extensions = const [];
  final Map<String, List<SitePlugin>> _pluginsByRepo = {};
  final Map<String, StreamProvider> _providerCache = {};

  void _loadData() {
    final raw = _dataBox.get('data');
    if (raw != null) {
      try {
        _data.addAll((jsonDecode(raw) as Map).cast<String, String>());
      } catch (_) {}
    }
    _reload();
  }

  void _reload() {
    _repos = _repoBox.values
        .whereType<String>()
        .map((s) {
          try {
            return ExtensionRepository.fromJson(jsonDecode(s) as Map<String, dynamic>, '');
          } catch (_) {
            return null;
          }
        })
        .whereType<ExtensionRepository>()
        .toList();
    _extensions = _pluginBox.values
        .whereType<String>()
        .map((s) {
          try {
            return InstalledExtension.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<InstalledExtension>()
        .toList();
    notifyListeners();
  }

  // ---- repositories --------------------------------------------------------

  List<ExtensionRepository> get repositories => List.unmodifiable(_repos);

  Future<ExtensionRepository> addRepository(String input) async {
    final repo = await repositoryService.fetchRepository(input);
    await _repoBox.put(repo.url, jsonEncode(repoToJson(repo)));
    addLog('info', 'Repository added');
    _reload();
    return repo;
  }

  Future<void> removeRepository(String url) async {
    await _repoBox.delete(url);
    _reload();
  }

  /// Fetches the plugin list for a repository (cached per session).
  Future<List<SitePlugin>> pluginsFor(ExtensionRepository repo) async {
    final cached = _pluginsByRepo[repo.url];
    if (cached != null) return cached;
    final plugins = await repositoryService.fetchPlugins(repo);
    _pluginsByRepo[repo.url] = plugins;
    return plugins;
  }

  // ---- extensions ----------------------------------------------------------

  List<InstalledExtension> get installed => List.unmodifiable(_extensions);

  InstalledExtension? extensionById(String packageName) {
    for (final e in _extensions) {
      if (e.packageName == packageName) return e;
    }
    return null;
  }

  Future<InstalledExtension> install(SitePlugin plugin, String repositoryUrl) async {
    final code = await repositoryService.downloadPluginCode(plugin);
    final record = InstalledExtension(
      packageName: plugin.packageName,
      name: plugin.name,
      version: plugin.version,
      repositoryUrl: repositoryUrl,
      fileUrl: plugin.url,
      code: code,
      description: plugin.description,
      authors: plugin.authors,
      iconUrl: plugin.iconUrl,
      language: plugin.language,
      tvTypes: plugin.tvTypes,
      enabled: true,
      installedAt: DateTime.now(),
    );
    await _pluginBox.put(plugin.packageName, jsonEncode(record.toJson()));
    addLog('info', 'Installed plugin');
    _reload();
    return record;
  }

  Future<void> uninstall(String packageName) async {
    await _pluginBox.delete(packageName);
    _providerCache.remove(packageName);
    _reload();
  }

  Future<void> setEnabled(String packageName, bool enabled) async {
    final ext = extensionById(packageName);
    if (ext == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    await _pluginBox.put(packageName, jsonEncode(ext.copyWith(enabled: enabled).toJson()));
    _providerCache.remove(packageName);
    addLog('info', enabled ? 'Plugin enabled' : 'Plugin disabled');
    _reload();
  }

  Future<void> update(String packageName) async {
    final ext = extensionById(packageName);
    if (ext == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    final repo = _repos.where((r) => r.url == ext.repositoryUrl).firstOrNull;
    if (repo == null) return;
    final plugins = await pluginsFor(repo);
    for (final p in plugins) {
      if (p.packageName == packageName && p.version > ext.version) {
        final code = await repositoryService.downloadPluginCode(p);
        await _pluginBox.put(packageName, jsonEncode(InstalledExtension(
          packageName: ext.packageName,
          name: p.name,
          version: p.version,
          repositoryUrl: ext.repositoryUrl,
          fileUrl: p.url,
          code: code,
          description: p.description,
          authors: p.authors,
          iconUrl: p.iconUrl,
          language: p.language,
          tvTypes: p.tvTypes,
          enabled: ext.enabled,
          installedAt: ext.installedAt,
          baseUrl: ext.baseUrl,
          settings: ext.settings,
        ).toJson()));
        addLog('info', 'Plugin updated');
        _reload();
        return;
      }
    }
  }

  /// Sets the base URL override that is injected as `manifest.baseUrl`.
  Future<void> configure(String packageName, {String? baseUrl, Map<String, dynamic>? settings}) async {
    final ext = extensionById(packageName);
    if (ext == null) throw const AppException(AppErrorKind.pluginNotFound, message: 'Plugin not found.');
    await _pluginBox.put(packageName, jsonEncode(ext.copyWith(baseUrl: baseUrl, settings: settings).toJson()));
    _reload();
  }

  // ---- providers -----------------------------------------------------------

  /// StreamProviders for every enabled extension. Each provider runs its
  /// extension's JavaScript in an isolated QuickJS runtime (cached per plugin).
  List<StreamProvider> enabledProviders() {
    final out = <StreamProvider>[];
    for (final ext in _extensions) {
      if (!ext.enabled) continue;
      if (ext.code.trim().isEmpty) continue;
      out.add(_providerCache.putIfAbsent(
        ext.packageName,
        () => JsExtensionProvider(
          extension: ext,
          runnerFactory: () => QuickJsExtensionRunner(
            script: ext.code,
            manifestJson: jsonEncode(ext.manifest),
            storage: _data,
            prefs: _data,
          ),
          api: _api,
        ),
      ));
    }
    return out;
  }

  // ---- misc ----------------------------------------------------------------

  final List<(DateTime, String, String)> _logs = [];

  List<(DateTime, String, String)> get logs => List.unmodifiable(_logs);

  void addLog(String level, String message) {
    _logs.add((DateTime.now(), level, message));
    if (_logs.length > 200) _logs.removeAt(0);
    notifyListeners();
  }

  Map<String, String> get data => _data;

  void persistData() {
    _dataBox.put('data', jsonEncode(_data));
  }
}

Map<String, dynamic> repoToJson(ExtensionRepository repo) => {
      'name': repo.name,
      'url': repo.url,
      'packageName': repo.packageName,
      'description': repo.description,
      'iconUrl': repo.iconUrl,
      'manifestVersion': repo.manifestVersion,
      'pluginLists': repo.pluginLists,
      'repos': repo.includedRepos,
      'plugins': repo.inlinePlugins.map((p) => {
            'url': p.url,
            'name': p.name,
            'version': p.version,
            'internalName': p.internalName,
            'status': p.status,
            'authors': p.authors,
            'description': p.description,
            'language': p.language,
            'iconUrl': p.iconUrl,
            'fileHash': p.fileHash,
            'tvTypes': p.tvTypes,
          }).toList(),
    };
