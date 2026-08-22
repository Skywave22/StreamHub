/// Strict validation for raw plugin URLs. Only legitimate HTTPS URLs are
/// accepted.
abstract final class UrlValidation {
  static const Set<String> allowedSchemes = {'https'};

  /// Returns a user-facing error string, or null when the URL is valid.
  static String? error(String? input) {
    final trimmed = input?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a plugin URL.';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return 'Enter a valid URL.';
    if (!allowedSchemes.contains(uri.scheme)) {
      return 'Only HTTPS URLs are supported.';
    }
    if (uri.host.isEmpty) return 'The URL must include a host.';
    return null;
  }

  static bool isValid(String? input) => error(input) == null;

  static String normalize(String input) => input.trim();
}
