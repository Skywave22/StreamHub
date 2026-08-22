import '../core/errors/app_exception.dart';
import '../core/platform/platform_info.dart';
import 'provider.dart';

/// Parsed, validated representation of a plugin manifest (manifest.json /
/// plugin.json) discovered at a plugin URL.
class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.platforms,
    required this.capabilities,
    this.description,
    this.updateUrl,
    this.mainEntry,
    this.checksum,
    this.signature,
    this.packageUrl,
    this.packageChecksum,
    this.permissions = const [],
    this.configSchema = const {},
  });

  final String id;
  final String name;
  final String version;
  final String? description;
  final Set<ProviderPlatform> platforms;
  final ProviderCapabilities capabilities;
  final String? updateUrl;

  /// Declared entry point of the plugin. NEVER executed by the core app; it is
  /// only recorded for the (isolated) native engine integration.
  final String? mainEntry;

  /// SHA-256 of the manifest document itself (integrity verification).
  final String? checksum;
  final String? signature;

  /// Optional downloadable package + its SHA-256. The package is downloaded for
  /// verification only and is never executed by the core application.
  final String? packageUrl;
  final String? packageChecksum;
  final List<String> permissions;
  final Map<String, dynamic> configSchema;

  bool isSupportedOn(AppPlatform platform) => platforms.contains(ProviderPlatform.fromAppPlatform(platform));

  bool isCompatibleWith(AppPlatform platform) => isSupportedOn(platform);

  static PluginManifest fromJson(Map<String, dynamic> json, {required String sourceUrl}) {
    final id = (json['id'] as String? ?? '').trim();
    final name = (json['name'] as String? ?? '').trim();
    final version = (json['version'] as String? ?? '').trim();

    if (id.isEmpty || name.isEmpty || version.isEmpty) {
      throw AppException(
        AppErrorKind.manifestInvalid,
        message: 'The plugin manifest is missing id, name or version.',
        technical: sourceUrl,
      );
    }
    if (!RegExp(r'^\d+\.\d+\.\d+').hasMatch(version)) {
      throw AppException(
        AppErrorKind.manifestInvalid,
        message: 'The plugin manifest has an invalid version (expected MAJOR.MINOR.PATCH).',
        technical: sourceUrl,
      );
    }

    final rawPlatforms = (json['platforms'] as List?)?.whereType<String>().toList() ?? const [];
    final platforms = rawPlatforms.isEmpty
        ? {ProviderPlatform.android, ProviderPlatform.windows, ProviderPlatform.linux}
        : rawPlatforms.map(ProviderPlatform.fromName).toSet();

    return PluginManifest(
      id: id,
      name: name,
      version: version,
      description: json['description'] as String?,
      platforms: platforms,
      capabilities: ProviderCapabilities.fromJson((json['capabilities'] as Map?)?.cast<String, dynamic>() ?? const {}),
      updateUrl: json['updateUrl'] as String?,
      mainEntry: json['mainEntry'] as String? ?? json['main'] as String?,
      checksum: json['checksum'] as String? ?? json['sha256'] as String?,
      signature: json['signature'] as String?,
      packageUrl: json['packageUrl'] as String?,
      packageChecksum: json['packageChecksum'] as String? ?? json['packageSha256'] as String?,
      permissions: (json['permissions'] as List?)?.whereType<String>().toList() ?? const [],
      configSchema: (json['configSchema'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}
