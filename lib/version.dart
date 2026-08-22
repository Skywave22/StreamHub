/// Central, single source of truth for the application identity and version.
/// Bump here when releasing; keep in sync with pubspec.yaml.
class AppInfo {
  AppInfo._();

  static const String name = 'StreamHub';
  static const String version = '1.1.0';
  static const int buildNumber = 2;
  static const String versionTag = 'v$version';

  static const String repository = 'https://github.com/Skywave22/StreamHub';
}
