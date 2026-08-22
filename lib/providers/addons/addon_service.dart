import '../../core/errors/app_exception.dart';
import '../../core/networking/api_client.dart';
import '../../core/utils/json_util.dart';
import 'addon_models.dart';

/// Talks to Nuvio/Stremio-compatible addons: manifest discovery, catalogs,
/// metadata and streams. A legitimate, open JSON protocol.
class AddonService {
  AddonService({required ApiClient api}) : _api = api;

  final ApiClient _api;

  Future<Map<String, dynamic>> _get(String url) async {
    final resp = await _api.get(url, cacheTtl: const Duration(minutes: 10));
    if (!resp.isOk) {
      throw AppException(AppErrorKind.providerUnavailable, message: 'The addon did not respond.', technical: url);
    }
    final json = resp.json;
    if (json == null) {
      throw const AppException(AppErrorKind.manifestInvalid, message: 'The addon returned invalid JSON.');
    }
    return json;
  }

  Future<AddonManifest> fetchManifest(String url) async {
    var candidate = url.trim();
    if (!candidate.endsWith('/manifest.json') && !candidate.endsWith('.json')) {
      candidate = candidate.endsWith('/') ? '${candidate}manifest.json' : '$candidate/manifest.json';
    }
    final json = await _get(candidate);
    final manifest = AddonManifest.fromJson(json, sourceUrl: candidate);
    if (!manifest.resources.contains('stream')) {
      throw const AppException(
        AppErrorKind.manifestInvalid,
        message: 'This addon does not provide streams.',
      );
    }
    return manifest;
  }

  /// Lists catalog entries (metas) for a catalog.
  Future<List<Map<String, dynamic>>> catalog(AddonManifest manifest, String base, String type, String catalogId) async {
    final json = await _get('${base}catalog/$type/$catalogId.json');
    return asMapList(json['metas']);
  }

  Future<Map<String, dynamic>> meta(AddonManifest manifest, String base, String type, String id) async {
    final json = await _get('${base}meta/$type/$id.json');
    final meta = json['meta'];
    return meta is Map ? Map<String, dynamic>.from(meta) : const {};
  }

  /// Streams for a given media id.
  Future<List<Map<String, dynamic>>> streams(AddonManifest manifest, String base, String type, String id) async {
    final json = await _get('${base}stream/$type/$id.json');
    return asMapList(json['streams']);
  }
}
