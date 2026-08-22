import 'app_exception.dart';

/// Maps error kinds to friendly, non-technical copy.
abstract final class ErrorMessages {
  static String forKind(AppErrorKind kind) {
    switch (kind) {
      case AppErrorKind.network:
        return 'Unable to connect to provider.\nTry again or reload the plugin.';
      case AppErrorKind.timeout:
        return 'The request timed out.\nCheck your connection and try again.';
      case AppErrorKind.providerUnavailable:
        return 'This provider is currently unavailable.\nTry again or reload the plugin.';
      case AppErrorKind.pluginIncompatible:
        return 'This plugin is not compatible with this platform.';
      case AppErrorKind.pluginNotFound:
        return 'Plugin not found.';
      case AppErrorKind.invalidPluginUrl:
        return 'That plugin URL is not valid.\nEnter a valid HTTPS plugin URL.';
      case AppErrorKind.invalidShortCode:
        return 'Invalid SkyStream short code.\nCheck the code and try again.';
      case AppErrorKind.manifestInvalid:
        return 'The plugin manifest is invalid or incomplete.';
      case AppErrorKind.checksumMismatch:
        return 'Plugin verification failed.\nThe checksum does not match — the plugin was not installed.';
      case AppErrorKind.pluginInstallFailed:
        return 'Plugin installation failed.\nCheck the URL and try again.';
      case AppErrorKind.tmdbAuth:
        return 'TMDB authentication failed.\nCheck your API key in Settings → TMDB.';
      case AppErrorKind.tmdbError:
        return 'TMDB is unavailable right now.\nPlease try again later.';
      case AppErrorKind.sourceUnavailable:
        return 'No playable source was found for this title.';
      case AppErrorKind.storage:
        return 'Could not save data on this device.\nCheck available storage.';
      case AppErrorKind.playback:
        return 'Playback failed.\nTry another source or check your connection.';
      case AppErrorKind.notSupported:
        return 'This feature is not supported on this platform.';
      case AppErrorKind.cancellation:
        return 'Operation cancelled.';
      case AppErrorKind.unknown:
        return 'Something went wrong.\nPlease try again.';
    }
  }

  static String forException(AppException e) => e.message.isNotEmpty ? e.message : forKind(e.kind);
}
