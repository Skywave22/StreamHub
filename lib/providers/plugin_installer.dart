import '../core/errors/app_exception.dart';
import '../core/networking/api_client.dart';
import '../core/platform/platform_info.dart';
import '../core/utils/checksum.dart';
import 'plugin_manifest.dart';
import 'provider.dart';
import 'shortcode_resolver.dart';
import 'sky/skystream_repo.dart';
import 'url_validation.dart';

/// Outcome of a successful plugin installation.
class InstallOutcome {
  const InstallOutcome({
    required this.plugin,
    required this.sourceUrl,
    this.manifest,
    this.repo,
    this.checksumVerified = false,
  });

  final InstalledPlugin plugin;
  final String sourceUrl;
  final PluginManifest? manifest;
  final SkyStreamRepo? repo;
  final bool checksumVerified;
}

/// Installs plugins from raw HTTPS URLs or SkyStream short codes.
///
/// Performs: URL validation → manifest/repository discovery → metadata parse →
/// version detection → compatibility checks → checksum verification (when the
/// manifest declares one) → installation record. Downloaded packages are never
/// executed by the core app.
class PluginInstaller {
  PluginInstaller({required ApiClient api, required ShortCodeResolver shortCodes})
      : _api = api,
        _shortCodes = shortCodes;

  final ApiClient _api;
  final ShortCodeResolver _shortCodes;

  static const int maxPackageBytes = 64 * 1024 * 1024;

  Future<InstallOutcome> install(String input, {AppPlatform? platform}) async {
    final trimmed = input.trim();
    final targetPlatform = platform ?? currentPlatform();

    // Short code (no scheme) → resolve → SkyStream repository.
    if (!trimmed.startsWith('http') && ShortCodeResolver.isValidFormat(trimmed)) {
      final repoUrl = await _shortCodes.resolve(trimmed);
      final repo = await fetchSkyStreamRepo(repoUrl);
      return InstallOutcome(
        plugin: _repoToPlugin(repo, repoUrl),
        sourceUrl: repoUrl,
        repo: repo,
      );
    }

    // Raw HTTPS URL.
    final validationError = UrlValidation.error(trimmed);
    if (validationError != null) {
      throw AppException(AppErrorKind.invalidPluginUrl, message: validationError);
    }

    final doc = await _fetchDocument(trimmed);
    if (doc.json == null) {
      throw const AppException(
        AppErrorKind.manifestInvalid,
        message: 'The plugin manifest is not valid JSON.',
      );
    }

    // A SkyStream repository manifest takes precedence when the shape matches.
    final repo = SkyStreamRepo.tryParse(doc.json!, trimmed);
    if (repo != null) {
      return InstallOutcome(
        plugin: _repoToPlugin(repo, trimmed),
        sourceUrl: trimmed,
        repo: repo,
      );
    }

    final manifest = PluginManifest.fromJson(doc.json!, sourceUrl: trimmed);
    if (!manifest.isCompatibleWith(targetPlatform)) {
      throw const AppException(
        AppErrorKind.pluginIncompatible,
        message: 'This plugin is not compatible with this platform.',
      );
    }

    // Checksum/signature verification when available: the declared checksum is
    // the SHA-256 of the downloadable package. The package is downloaded,
    // hashed, verified and discarded — never executed by the core app.
    var checksumVerified = false;
    final packageChecksum = manifest.packageChecksum ?? manifest.checksum;
    if (manifest.packageUrl != null && packageChecksum != null && packageChecksum.isNotEmpty) {
      await _verifyPackage(manifest.packageUrl!, packageChecksum);
      checksumVerified = true;
    }

    return InstallOutcome(
      plugin: InstalledPlugin(
        id: manifest.id,
        name: manifest.name,
        version: manifest.version,
        description: manifest.description,
        origin: PluginOrigin.url,
        sourceUrl: trimmed,
        updateUrl: manifest.updateUrl,
        platforms: manifest.platforms,
        capabilities: manifest.capabilities,
        enabled: true,
        installedAt: DateTime.now(),
        checksum: packageChecksum,
        permissions: manifest.permissions,
        config: manifest.configSchema.isEmpty ? const {} : {'schema': manifest.configSchema},
      ),
      sourceUrl: trimmed,
      manifest: manifest,
      checksumVerified: checksumVerified,
    );
  }

  /// Fetches and parses a generic plugin manifest (id/name/version) at [url].
  Future<PluginManifest> fetchManifest(String url) async {
    final validationError = UrlValidation.error(url);
    if (validationError != null) {
      throw AppException(AppErrorKind.invalidPluginUrl, message: validationError);
    }
    final doc = await _fetchDocument(url);
    if (doc.json == null) {
      throw const AppException(AppErrorKind.manifestInvalid, message: 'The plugin manifest is not valid JSON.');
    }
    return PluginManifest.fromJson(doc.json!, sourceUrl: url);
  }

  /// Fetches and parses a SkyStream repository manifest at [url].
  Future<SkyStreamRepo> fetchSkyStreamRepo(String url) async {
    final validationError = UrlValidation.error(url);
    if (validationError != null) {
      throw AppException(AppErrorKind.invalidPluginUrl, message: validationError);
    }
    final doc = await _fetchDocument(url);
    final repo = doc.json == null ? null : SkyStreamRepo.tryParse(doc.json!, url);
    if (repo == null) {
      throw const AppException(
        AppErrorKind.manifestInvalid,
        message: 'The repository manifest is invalid or incomplete.',
      );
    }
    return repo;
  }

  Future<({Map<String, dynamic>? json, List<int> rawBytes})> _fetchDocument(String url) async {
    final candidates = <String>[];
    final path = Uri.tryParse(url)?.path ?? '';
    if (path.endsWith('.json')) {
      candidates.add(url);
    } else {
      final base = url.endsWith('/') ? url : '$url/';
      candidates.add('${base}manifest.json');
      candidates.add('${base}plugin.json');
    }

    AppException? lastError;
    for (final candidate in candidates) {
      try {
        final resp = await _api.get(candidate, cacheTtl: const Duration(minutes: 5));
        if (resp.isOk) {
          final parsed = resp.json;
          if (parsed != null) {
            return (json: parsed, rawBytes: resp.bodyBytes);
          }
          lastError = const AppException(
            AppErrorKind.manifestInvalid,
            message: 'The plugin manifest is not valid JSON.',
          );
        } else {
          lastError = HttpException(
            resp.statusCode,
            message: 'Could not fetch the plugin manifest.',
            technical: candidate,
          );
        }
      } on HttpException catch (e) {
        lastError = e;
      }
    }
    throw lastError ??
        AppException(
          AppErrorKind.pluginInstallFailed,
          message: 'Could not discover a plugin manifest at this URL.',
          technical: url,
        );
  }

  Future<void> _verifyPackage(String packageUrl, String expectedSha256) async {
    final resp = await _api.get(packageUrl, cacheTtl: const Duration(minutes: 5));
    if (!resp.isOk) {
      throw AppException(
        AppErrorKind.pluginInstallFailed,
        message: 'Could not download the plugin package.',
        technical: packageUrl,
      );
    }
    if (resp.bodyBytes.length > maxPackageBytes) {
      throw const AppException(
        AppErrorKind.pluginInstallFailed,
        message: 'Plugin package is too large.',
      );
    }
    final actual = Checksum.sha256HexBytes(resp.bodyBytes);
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      throw const AppException(
        AppErrorKind.checksumMismatch,
        message: 'Plugin verification failed.\nThe package checksum does not match — the plugin was not installed.',
      );
    }
    // The package is verified and intentionally discarded. The core app never
    // executes downloaded plugin code.
  }

  InstalledPlugin _repoToPlugin(SkyStreamRepo repo, String sourceUrl) {
    return InstalledPlugin(
      id: repo.id,
      name: repo.name,
      version: '1.0.0',
      description: repo.description,
      origin: PluginOrigin.url,
      sourceUrl: sourceUrl,
      platforms: const {
        ProviderPlatform.android,
        ProviderPlatform.windows,
        ProviderPlatform.linux,
      },
      capabilities: const ProviderCapabilities(
        search: true,
        details: true,
        sources: true,
        resolveSource: true,
      ),
      enabled: true,
      installedAt: DateTime.now(),
      permissions: const ['network'],
      config: {
        'manifestVersion': repo.manifestVersion,
        'pluginLists': repo.pluginLists,
        'includedRepos': repo.includedRepos,
        'pluginCount': repo.pluginCount,
        'type': 'skystream-repository',
      },
    );
  }
}

