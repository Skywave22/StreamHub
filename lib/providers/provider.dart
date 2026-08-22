import '../core/errors/app_exception.dart';
import '../core/models/episode.dart';
import '../core/models/media_details.dart';
import '../core/models/media_item.dart';
import '../core/models/media_source.dart';
import '../core/models/search_filter.dart';
import '../core/models/season.dart';
import '../core/platform/platform_info.dart';

/// Platforms a provider declares support for.
enum ProviderPlatform {
  android('Android'),
  windows('Windows'),
  linux('Linux');

  const ProviderPlatform(this.label);
  final String label;

  static ProviderPlatform fromAppPlatform(AppPlatform p) => switch (p) {
        AppPlatform.android => ProviderPlatform.android,
        AppPlatform.windows => ProviderPlatform.windows,
        AppPlatform.linux => ProviderPlatform.linux,
        AppPlatform.other => ProviderPlatform.linux,
      };

  static ProviderPlatform fromName(String? v) {
    for (final p in values) {
      if (p.name == v) return p;
    }
    return ProviderPlatform.android;
  }
}

/// Declared capabilities of a provider.
class ProviderCapabilities {
  const ProviderCapabilities({
    this.search = false,
    this.details = false,
    this.seasons = false,
    this.episodes = false,
    this.sources = false,
    this.resolveSource = false,
    this.subtitles = false,
    this.trailers = false,
    this.shortCode = false,
  });

  final bool search;
  final bool details;
  final bool seasons;
  final bool episodes;
  final bool sources;
  final bool resolveSource;
  final bool subtitles;
  final bool trailers;
  final bool shortCode;

  List<String> get labels => [
        if (search) 'Search',
        if (details) 'Details',
        if (seasons) 'Seasons',
        if (episodes) 'Episodes',
        if (sources) 'Sources',
        if (resolveSource) 'Resolve',
        if (subtitles) 'Subtitles',
        if (trailers) 'Trailers',
        if (shortCode) 'Short codes',
      ];

  Map<String, dynamic> toJson() => {
        'search': search,
        'details': details,
        'seasons': seasons,
        'episodes': episodes,
        'sources': sources,
        'resolveSource': resolveSource,
        'subtitles': subtitles,
        'trailers': trailers,
        'shortCode': shortCode,
      };

  factory ProviderCapabilities.fromJson(Map<String, dynamic> json) => ProviderCapabilities(
        search: json['search'] == true,
        details: json['details'] == true,
        seasons: json['seasons'] == true,
        episodes: json['episodes'] == true,
        sources: json['sources'] == true,
        resolveSource: json['resolveSource'] == true,
        subtitles: json['subtitles'] == true,
        trailers: json['trailers'] == true,
        shortCode: json['shortCode'] == true,
      );
}

enum ProviderStatus { enabled, disabled, error, updating }

enum PluginOrigin { bundled, url }

/// Lifecycle + metadata record for an installed provider/plugin.
class InstalledPlugin {
  const InstalledPlugin({
    required this.id,
    required this.name,
    required this.version,
    required this.origin,
    required this.platforms,
    required this.capabilities,
    required this.enabled,
    required this.installedAt,
    this.description,
    this.sourceUrl,
    this.checksum,
    this.updateUrl,
    this.updateAvailable,
    this.permissions = const [],
    this.config = const {},
    this.status = ProviderStatus.enabled,
    this.lastError,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final PluginOrigin origin;
  final String? sourceUrl;
  final String? updateUrl;
  final Set<ProviderPlatform> platforms;
  final ProviderCapabilities capabilities;
  final bool enabled;
  final DateTime installedAt;
  final DateTime? updatedAt;
  final String? checksum;
  final String? updateAvailable;
  final List<String> permissions;
  final Map<String, dynamic> config;
  final ProviderStatus status;
  final String? lastError;

  bool isSupportedOn(AppPlatform p) => platforms.contains(ProviderPlatform.fromAppPlatform(p));

  InstalledPlugin copyWith({
    bool? enabled,
    ProviderStatus? status,
    String? lastError,
    String? version,
    String? name,
    String? description,
    String? updateAvailable,
    Map<String, dynamic>? config,
    DateTime? updatedAt,
    Set<ProviderPlatform>? platforms,
    ProviderCapabilities? capabilities,
    String? checksum,
  }) {
    return InstalledPlugin(
      id: id,
      name: name ?? this.name,
      version: version ?? this.version,
      description: description ?? this.description,
      origin: origin,
      sourceUrl: sourceUrl,
      updateUrl: updateUrl,
      platforms: platforms ?? this.platforms,
      capabilities: capabilities ?? this.capabilities,
      enabled: enabled ?? this.enabled,
      installedAt: installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checksum: checksum ?? this.checksum,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      permissions: permissions,
      config: config ?? this.config,
      status: status ?? this.status,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'origin': origin.name,
        'sourceUrl': sourceUrl,
        'updateUrl': updateUrl,
        'platforms': platforms.map((p) => p.name).toList(),
        'capabilities': capabilities.toJson(),
        'enabled': enabled,
        'installedAt': installedAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'checksum': checksum,
        'updateAvailable': updateAvailable,
        'permissions': permissions,
        'config': config,
        'status': status.name,
        'lastError': lastError,
      };

  factory InstalledPlugin.fromJson(Map<String, dynamic> json) => InstalledPlugin(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        version: json['version'] as String? ?? '0.0.0',
        description: json['description'] as String?,
        origin: json['origin'] == 'url' ? PluginOrigin.url : PluginOrigin.bundled,
        sourceUrl: json['sourceUrl'] as String?,
        updateUrl: json['updateUrl'] as String?,
        platforms: (json['platforms'] as List? ?? const [])
            .whereType<String>()
            .map(ProviderPlatform.fromName)
            .toSet(),
        capabilities: ProviderCapabilities.fromJson((json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {}),
        enabled: json['enabled'] as bool? ?? true,
        installedAt: DateTime.tryParse(json['installedAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
        checksum: json['checksum'] as String?,
        updateAvailable: json['updateAvailable'] as String?,
        permissions: (json['permissions'] as List?)?.whereType<String>().toList() ?? const [],
        config: (json['config'] as Map?)?.cast<String, dynamic>() ?? const {},
        status: ProviderStatus.values.asNameMap()[json['status'] as String?] ?? ProviderStatus.enabled,
        lastError: json['lastError'] as String?,
      );
}

/// The common provider interface. The core application depends only on this
/// contract — never on a concrete provider — so providers can be installed,
/// enabled, disabled, updated, reloaded, removed and configured independently.
abstract class StreamProvider {
  String get id;
  String get name;
  String get version;
  String get description;
  Set<ProviderPlatform> get supportedPlatforms;
  ProviderCapabilities get capabilities;

  bool isSupportedOn(AppPlatform platform) =>
      supportedPlatforms.contains(ProviderPlatform.fromAppPlatform(platform));

  Future<void> initialize() async {}

  Future<void> shutdown() async {}

  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1}) async => const [];

  Future<MediaDetails?> getDetails(String mediaId) async => null;

  Future<List<Season>> getSeasons(String mediaId) async => const [];

  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber) async => const [];

  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode}) async => const [];

  Future<MediaSource> resolveSource(MediaSource source) async {
    throw const AppException(AppErrorKind.sourceUnavailable, message: 'This provider cannot resolve sources.');
  }
}
