import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/utils/json_util.dart';

/// Plugin status ints as used by CloudStream/SkyStream repositories:
/// 0 down, 1 ok, 2 slow, 3 beta.
enum ExtensionStatus { down, ok, slow, beta }

ExtensionStatus statusFromInt(int? v) {
  switch (v) {
    case 0:
      return ExtensionStatus.down;
    case 2:
      return ExtensionStatus.slow;
    case 3:
      return ExtensionStatus.beta;
    default:
      return ExtensionStatus.ok;
  }
}

/// A repository manifest (CloudStream / SkyStream "Enterprise V2" schema).
class ExtensionRepository {
  const ExtensionRepository({
    required this.name,
    required this.url,
    required this.manifestVersion,
    required this.pluginLists,
    required this.includedRepos,
    required this.inlinePlugins,
    this.packageName,
    this.description,
    this.iconUrl,
  });

  final String name;
  final String url;
  final String? packageName;
  final String? description;
  final String? iconUrl;
  final int manifestVersion;
  final List<String> pluginLists;
  final List<String> includedRepos;
  final List<SitePlugin> inlinePlugins;

  int get pluginCount => inlinePlugins.length + pluginLists.length;

  String get id => packageName ?? 'repo-${url.hashCode.toRadixString(16)}';

  static bool looksLike(Map<String, dynamic> json) {
    final name = json['name'];
    final hasId = json['packageName'] != null || json['id'] != null;
    final hasPlugins = asList(json, 'pluginLists').isNotEmpty ||
        asList(json, 'repos').isNotEmpty ||
        asList(json, 'plugins').isNotEmpty;
    return name is String && name.isNotEmpty && hasId && hasPlugins;
  }

  static ExtensionRepository fromJson(Map<String, dynamic> json, String url) {
    final inline = <SitePlugin>[];
    for (final p in asMapList(json['plugins'])) {
      try {
        inline.add(SitePlugin.fromJson(p));
      } catch (_) {
        // skip malformed inline plugin entries
      }
    }
    return ExtensionRepository(
      name: asString(json, 'name') ?? 'Unknown repository',
      url: url,
      packageName: asString(json, 'packageName') ?? asString(json, 'id'),
      description: asString(json, 'description'),
      iconUrl: asString(json, 'iconUrl'),
      manifestVersion: asInt(json, 'manifestVersion') ?? 1,
      pluginLists: asList(json, 'pluginLists').whereType<String>().toList(),
      includedRepos: asList(json, 'repos').whereType<String>().toList(),
      inlinePlugins: inline,
    );
  }
}

/// A single extension/plugin descriptor as listed inside a repository
/// (mirrors CloudStream's `SitePlugin` schema).
class SitePlugin {
  const SitePlugin({
    required this.url,
    required this.name,
    required this.version,
    required this.internalName,
    this.status = 1,
    this.apiVersion = 1,
    this.authors = const [],
    this.description,
    this.repositoryUrl,
    this.tvTypes = const [],
    this.language,
    this.iconUrl,
    this.fileHash,
    this.fileSize,
  });

  final String url;
  final String name;
  final int version;
  final String internalName;
  final int status;
  final int apiVersion;
  final List<String> authors;
  final String? description;
  final String? repositoryUrl;
  final List<String> tvTypes;
  final String? language;
  final String? iconUrl;
  final String? fileHash;
  final int? fileSize;

  String get packageName => internalName;

  factory SitePlugin.fromJson(Map<String, dynamic> json) {
    final url = asString(json, 'url') ?? asString(json, 'fileUrl') ?? '';
    final name = asString(json, 'name') ?? '';
    final internal = asString(json, 'internalName') ??
        asString(json, 'packageName') ??
        asString(json, 'id') ??
        '';
    if (url.isEmpty || name.isEmpty || internal.isEmpty) {
      throw const AppException(AppErrorKind.manifestInvalid, message: 'Plugin entry is incomplete.');
    }
    return SitePlugin(
      url: url,
      name: name,
      version: asInt(json, 'version') ?? 1,
      internalName: internal,
      status: asInt(json, 'status') ?? 1,
      apiVersion: asInt(json, 'apiVersion') ?? 1,
      authors: asList(json, 'authors').whereType<String>().toList(),
      description: asString(json, 'description'),
      repositoryUrl: asString(json, 'repositoryUrl'),
      tvTypes: asList(json, 'tvTypes').whereType<String>().toList(),
      language: asString(json, 'language'),
      iconUrl: asString(json, 'iconUrl'),
      fileHash: asString(json, 'fileHash'),
      fileSize: asInt(json, 'fileSize'),
    );
  }
}

/// An installed extension (JS plugin) persisted locally.
class InstalledExtension {
  const InstalledExtension({
    required this.packageName,
    required this.name,
    required this.version,
    required this.repositoryUrl,
    required this.fileUrl,
    required this.code,
    this.description,
    this.authors = const [],
    this.iconUrl,
    this.language,
    this.tvTypes = const [],
    this.enabled = true,
    this.installedAt,
    this.baseUrl,
    this.settings = const {},
  });

  final String packageName;
  final String name;
  final int version;
  final String repositoryUrl;
  final String fileUrl;
  final String code;
  final String? description;
  final List<String> authors;
  final String? iconUrl;
  final String? language;
  final List<String> tvTypes;
  final bool enabled;
  final DateTime? installedAt;
  final String? baseUrl;
  final Map<String, dynamic> settings;

  Map<String, dynamic> get manifest => {
        'packageName': packageName,
        'name': name,
        'version': version,
        'baseUrl': baseUrl ?? '',
        'description': description ?? '',
        'authors': authors,
        'languages': language == null ? const <String>[] : [language!],
        'categories': tvTypes,
      };

  InstalledExtension copyWith({bool? enabled, String? baseUrl, Map<String, dynamic>? settings}) =>
      InstalledExtension(
        packageName: packageName,
        name: name,
        version: version,
        repositoryUrl: repositoryUrl,
        fileUrl: fileUrl,
        code: code,
        description: description,
        authors: authors,
        iconUrl: iconUrl,
        language: language,
        tvTypes: tvTypes,
        enabled: enabled ?? this.enabled,
        installedAt: installedAt,
        baseUrl: baseUrl ?? this.baseUrl,
        settings: settings ?? this.settings,
      );

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'name': name,
        'version': version,
        'repositoryUrl': repositoryUrl,
        'fileUrl': fileUrl,
        'code': code,
        'description': description,
        'authors': authors,
        'iconUrl': iconUrl,
        'language': language,
        'tvTypes': tvTypes,
        'enabled': enabled,
        'installedAt': installedAt?.toIso8601String(),
        'baseUrl': baseUrl,
        'settings': settings,
      };

  factory InstalledExtension.fromJson(Map<String, dynamic> json) => InstalledExtension(
        packageName: json['packageName'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as int? ?? 1,
        repositoryUrl: json['repositoryUrl'] as String? ?? '',
        fileUrl: json['fileUrl'] as String? ?? '',
        code: json['code'] as String? ?? '',
        description: json['description'] as String?,
        authors: (json['authors'] as List?)?.whereType<String>().toList() ?? const [],
        iconUrl: json['iconUrl'] as String?,
        language: json['language'] as String?,
        tvTypes: (json['tvTypes'] as List?)?.whereType<String>().toList() ?? const [],
        enabled: json['enabled'] as bool? ?? true,
        installedAt: DateTime.tryParse(json['installedAt'] as String? ?? ''),
        baseUrl: json['baseUrl'] as String?,
        settings: (json['settings'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

/// Parses a fetched plugin-list document (flexible shape) into plugin entries.
List<SitePlugin> parsePluginListDocument(dynamic doc, {required String repositoryUrl}) {
  final out = <SitePlugin>[];
  void addAll(Iterable<dynamic> items) {
    for (final item in items) {
      if (item is! Map) continue;
      try {
        out.add(SitePlugin.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // skip malformed entries
      }
    }
  }

  if (doc is List) {
    addAll(doc);
  } else if (doc is Map) {
    final m = Map<String, dynamic>.from(doc);
    // Inline "plugins" array (Enterprise V2)
    final plugins = m['plugins'];
    if (plugins is List) addAll(plugins);
    // CloudStream plugin lists are grouped: { "<repo name>": [ ...plugins ] }
    var foundGroup = false;
    for (final entry in m.entries) {
      if (entry.value is List) {
        foundGroup = true;
        addAll(entry.value as List);
      }
    }
    if (!foundGroup && plugins == null) {
      // A single plugin object?
      if (m.containsKey('internalName') || m.containsKey('url')) addAll([m]);
    }
  }
  return out;
}

String encodeRepoRecord(ExtensionRepository repo) => jsonEncode({
      'name': repo.name,
      'url': repo.url,
      'packageName': repo.packageName,
      'description': repo.description,
      'iconUrl': repo.iconUrl,
      'manifestVersion': repo.manifestVersion,
      'pluginLists': repo.pluginLists,
      'includedRepos': repo.includedRepos,
      'inlinePlugins': repo.inlinePlugins.map((p) => {
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
    });
