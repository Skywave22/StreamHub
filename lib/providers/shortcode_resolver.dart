import '../core/errors/app_exception.dart';
import '../core/networking/api_client.dart';

/// Resolves SkyStream short codes to repository URLs.
///
/// Short codes use the same public mechanism as the SkyStream application: a
/// URL-shortener prefix (`https://cutt.ly/sky-<code>`) that redirects to the
/// repository URL. Invalid codes resolve to a 404 page and are reported as
/// invalid — short codes are never fabricated.
class ShortCodeResolver {
  ShortCodeResolver({
    required ApiClient api,
    this.endpoint = 'https://cutt.ly/sky-',
    this.builtinFallback = const {},
  }) : _api = api;

  final ApiClient _api;
  final String endpoint;

  /// Optional offline fallback of verified, well-known codes. Consulted only
  /// when the remote lookup fails due to a network error (never for a
  /// genuine "code not found").
  final Map<String, String> builtinFallback;

  static final RegExp codePattern = RegExp(r'^[a-zA-Z0-9!_-]+$');

  static bool isValidFormat(String code) => codePattern.hasMatch(code.trim());

  /// Returns the repository URL for [rawCode], or throws a user-friendly
  /// [AppException] when the code is invalid or unresolvable.
  Future<String> resolve(String rawCode) async {
    final code = rawCode.trim();
    if (code.isEmpty || !isValidFormat(code)) {
      throw const AppException(
        AppErrorKind.invalidShortCode,
        message: 'Invalid SkyStream short code.\nCheck the code and try again.',
      );
    }

    try {
      final result = await _api.resolveRedirect('$endpoint$code');
      if (result.found && result.location != null) {
        final location = result.location!.trim();
        final normalized = location.replaceAll(RegExp(r'/$'), '');
        // cutt.ly sends unresolved codes to its 404 page.
        if (location.startsWith('https://cutt.ly/404') || normalized == 'https://cutt.ly') {
          throw const AppException(
            AppErrorKind.invalidShortCode,
            message: 'Invalid SkyStream short code.\nCheck the code and try again.',
          );
        }
        return location;
      }
      throw const AppException(
        AppErrorKind.invalidShortCode,
        message: 'Invalid SkyStream short code.\nCheck the code and try again.',
      );
    } on AppException catch (e) {
      if (e.kind == AppErrorKind.invalidShortCode) rethrow;
      // Network failure: fall back to the built-in registry when possible.
      final fallback = builtinFallback[code.toLowerCase()];
      if (fallback != null) return fallback;
      rethrow;
    }
  }
}
