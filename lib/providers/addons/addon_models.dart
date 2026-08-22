import '../../core/errors/app_exception.dart';
import '../../core/utils/json_util.dart';

/// A Nuvio/Stremio-compatible addon manifest.
class AddonManifest {
  const AddonManifest({
    required this.id,
    required this.name,
    required this.version,
    this.description,
    this.logoUrl,
    this.resources = const [],
    this.types = const [],
    this.idPrefixes = const [],
    this.catalogs = const [],
    this.transportUrl,
    this.configurable = false,
    this.adult = false,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final String? logoUrl;
  final List<String> resources;
  final List<String> types;
  final List<String> idPrefixes;
  final List<AddonCatalog> catalogs;

  /// Explicit transport base (Nuvio extension of the Stremio schema).
  final String? transportUrl;
  final bool configurable;
  final bool adult;

  static AddonManifest fromJson(Map<String, dynamic> json, {required String sourceUrl}) {
    final id = (json['id'] ?? '').toString().trim();
    final name = (json['name'] ?? '').toString().trim();
    final version = (json['version'] ?? '').toString().trim();
    if (id.isEmpty || name.isEmpty || version.isEmpty) {
      throw const AppException(AppErrorKind.manifestInvalid, message: 'The addon manifest is incomplete.');
    }

    // Stremio: "resources": ["catalog","meta","stream"].
    // Nuvio: "resources": [{"name":"stream","types":[...]}].
    final resources = <String>[];
    for (final r in asList(json, 'resources')) {
      if (r is String) {
        resources.add(r);
      } else if (r is Map) {
        final n = r['name'];
        if (n is String) resources.add(n);
      }
    }

    final catalogs = <AddonCatalog>[];
    for (final c in asMapList(json['catalogs'])) {
      catalogs.add(AddonCatalog(
        type: (c['type'] ?? '').toString(),
        id: (c['id'] ?? '').toString(),
        name: (c['name'] ?? c['id'] ?? '').toString(),
      ));
    }

    final behavior = asMap(json, 'behaviorHints');
    return AddonManifest(
      id: id,
      name: name,
      version: version,
      description: json['description'] as String?,
      logoUrl: json['logo'] as String? ?? json['logoUrl'] as String?,
      resources: resources,
      types: asList(json, 'types').whereType<String>().toList(),
      idPrefixes: asList(json, 'idPrefixes').whereType<String>().toList(),
      catalogs: catalogs,
      transportUrl: json['transportUrl'] as String?,
      configurable: behavior['configurable'] == true,
      adult: behavior['adult'] == true,
    );
  }

  /// The base URL used for addon API requests.
  String baseUrl(String sourceUrl) {
    if (transportUrl != null && transportUrl!.isNotEmpty) {
      final t = transportUrl!;
      return t.endsWith('/') ? t : '$t/';
    }
    final u = Uri.parse(sourceUrl);
    final path = u.path;
    final basePath = path.endsWith('/manifest.json') ? path.substring(0, path.length - 'manifest.json'.length) : '/';
    return '${u.scheme}://${u.host}${basePath.endsWith('/') ? basePath : '$basePath/'}';
  }
}

class AddonCatalog {
  const AddonCatalog({required this.type, required this.id, required this.name});
  final String type;
  final String id;
  final String name;
}

/// A persisted, user-managed addon.
class ManagedAddon {
  const ManagedAddon({
    required this.manifestUrl,
    required this.manifest,
    this.enabled = true,
  });

  final String manifestUrl;
  final AddonManifest manifest;
  final bool enabled;

  ManagedAddon copyWith({bool? enabled, AddonManifest? manifest}) => ManagedAddon(
        manifestUrl: manifestUrl,
        manifest: manifest ?? this.manifest,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'manifestUrl': manifestUrl,
        'enabled': enabled,
        'manifest': {
          'id': manifest.id,
          'name': manifest.name,
          'version': manifest.version,
          'description': manifest.description,
          'logoUrl': manifest.logoUrl,
          'resources': manifest.resources,
          'types': manifest.types,
          'idPrefixes': manifest.idPrefixes,
          'transportUrl': manifest.transportUrl,
          'configurable': manifest.configurable,
          'adult': manifest.adult,
        },
      };

  factory ManagedAddon.fromJson(Map<String, dynamic> json) {
    final m = (json['manifest'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ManagedAddon(
      manifestUrl: json['manifestUrl'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      manifest: AddonManifest.fromJson(m, sourceUrl: json['manifestUrl'] as String? ?? ''),
    );
  }
}
