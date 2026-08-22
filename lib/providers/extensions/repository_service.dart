import 'dart:convert';

import '../../core/errors/app_exception.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/checksum.dart';
import 'extension_models.dart';

/// Resolves and fetches SkyStream/CloudStream repositories and plugins.
///
/// Real mechanics, mirroring the official apps:
/// - Short codes resolve through `https://cutt.ly/sky-<code>` (redirect).
/// - Raw GitHub URLs are optionally normalised to jsDelivr.
/// - Repository manifests use the "Enterprise V2" schema.
/// - Plugin lists are fetched and parsed into `SitePlugin` descriptors.
class RepositoryService {
  RepositoryService({
    required ApiClient api,
    this.shortCodeEndpoint = 'https://cutt.ly/sky-',
    this.enableJsdelivrProxy = true,
  }) : _api = api;

  final ApiClient _api;
  final String shortCodeEndpoint;
  final bool enableJsdelivrProxy;

  static final RegExp shortCodePattern = RegExp(r'^[a-zA-Z0-9!_-]+$');
  static final RegExp rawGithubPattern =
      RegExp(r'^https://raw\.githubusercontent\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)/(.+)$');

  bool get isShortCode => true;

  static bool looksLikeShortCode(String input) => shortCodePattern.hasMatch(input.trim());

  String normalizeUrl(String url) {
    if (!enableJsdelivrProxy) return url;
    final m = rawGithubPattern.firstMatch(url);
    if (m == null) return url;
    return 'https://cdn.jsdelivr.net/gh/${m.group(1)}/${m.group(2)}@${m.group(3)}';
  }

  /// Resolves an input (short code or URL) into a fetchable URL.
  Future<String> resolveUrl(String input) async {
    final trimmed = input.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return normalizeUrl(trimmed);
    }
    if (looksLikeShortCode(trimmed)) {
      final result = await _api.resolveRedirect('$shortCodeEndpoint$trimmed');
      if (result.found && result.location != null) {
        final location = result.location!.trim();
        final stripped = location.replaceAll(RegExp(r'/$'), '');
        if (location.startsWith('https://cutt.ly/404') || stripped == 'https://cutt.ly') {
          throw const AppException(
            AppErrorKind.invalidShortCode,
            message: 'Invalid SkyStream short code.\nCheck the code and try again.',
          );
        }
        return normalizeUrl(location);
      }
      throw const AppException(
        AppErrorKind.invalidShortCode,
        message: 'Invalid SkyStream short code.\nCheck the code and try again.',
      );
    }
    throw const AppException(
      AppErrorKind.invalidPluginUrl,
      message: 'Enter a valid HTTPS plugin URL or SkyStream short code.',
    );
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final resp = await _api.get(url, cacheTtl: const Duration(minutes: 10));
    if (!resp.isOk) {
      throw AppException(
        AppErrorKind.providerUnavailable,
        message: 'Could not reach the repository.',
        technical: url,
      );
    }
    final json = resp.json;
    if (json == null) {
      throw const AppException(AppErrorKind.manifestInvalid, message: 'The repository returned invalid JSON.');
    }
    return json;
  }

  Future<ExtensionRepository> fetchRepository(String url) async {
    final resolved = await resolveUrl(url);
    final json = await _getJson(resolved);
    if (!ExtensionRepository.looksLike(json)) {
      throw const AppException(
        AppErrorKind.manifestInvalid,
        message: 'The repository manifest is invalid or incomplete.',
      );
    }
    return ExtensionRepository.fromJson(json, resolved);
  }

  /// Fetches every plugin listed by a repository (inline + plugin lists).
  Future<List<SitePlugin>> fetchPlugins(ExtensionRepository repo) async {
    final out = <SitePlugin>[...repo.inlinePlugins];
    for (final listUrl in repo.pluginLists) {
      try {
        final resolved = normalizeUrl(listUrl);
        final resp = await _api.get(resolved, cacheTtl: const Duration(minutes: 10));
        if (!resp.isOk) continue;
        final doc = resp.json;
        if (doc != null) {
          out.addAll(parsePluginListDocument(doc, repositoryUrl: repo.url));
        }
      } on AppException {
        // a failing plugin list should not abort the whole repo
      }
    }
    // Deduplicate by internal name.
    final seen = <String>{};
    return out.where((p) => seen.add(p.packageName)).toList();
  }

  /// Downloads a plugin's JS source and verifies its SHA-256 when declared.
  Future<String> downloadPluginCode(SitePlugin plugin) async {
    final url = normalizeUrl(plugin.url);
    final resp = await _api.get(url, cacheTtl: const Duration(hours: 1));
    if (!resp.isOk) {
      throw AppException(
        AppErrorKind.pluginInstallFailed,
        message: 'Could not download the plugin.',
        technical: url,
      );
    }
    if (plugin.fileHash != null && plugin.fileHash!.isNotEmpty) {
      final actual = Checksum.sha256HexBytes(resp.bodyBytes);
      final expected = plugin.fileHash!.replaceFirst(RegExp(r'^sha256-'), '').toLowerCase();
      if (actual.toLowerCase() != expected) {
        throw const AppException(
          AppErrorKind.checksumMismatch,
          message: 'Plugin verification failed.\nThe checksum does not match — the plugin was not installed.',
        );
      }
    }
    final code = utf8.decode(resp.bodyBytes, allowMalformed: true);
    if (code.trim().isEmpty) {
      throw const AppException(AppErrorKind.pluginInstallFailed, message: 'The plugin file is empty.');
    }
    return code;
  }
}
