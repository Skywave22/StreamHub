/// Structured, user-facing error kinds. UI must never surface raw stack traces
/// or technical details; it should map these kinds to friendly messages.
enum AppErrorKind {
  network,
  timeout,
  providerUnavailable,
  pluginIncompatible,
  pluginNotFound,
  invalidPluginUrl,
  invalidShortCode,
  manifestInvalid,
  checksumMismatch,
  pluginInstallFailed,
  tmdbAuth,
  tmdbError,
  sourceUnavailable,
  storage,
  playback,
  notSupported,
  cancellation,
  unknown,
}

class AppException implements Exception {
  const AppException(
    this.kind, {
    required this.message,
    this.technical,
    this.cause,
  });

  /// A user-facing message (safe to display).
  final String message;

  /// The broad category of the failure.
  final AppErrorKind kind;

  /// Technical detail for logs only — never render this in the UI.
  final String? technical;

  final Object? cause;

  @override
  String toString() =>
      'AppException(${kind.name}): $message${technical == null ? '' : ' [$technical]'}';
}

/// Thrown when an operation is cancelled by the user or the system.
class CancelledException extends AppException {
  const CancelledException()
      : super(AppErrorKind.cancellation, message: 'Operation cancelled.');
}
