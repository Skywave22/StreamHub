import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// The platforms StreamHub ships on.
enum AppPlatform {
  android('Android'),
  windows('Windows'),
  linux('Linux'),
  other('Other');

  const AppPlatform(this.label);

  final String label;

  bool get isDesktop => this == AppPlatform.windows || this == AppPlatform.linux;

  bool get isMobile => this == AppPlatform.android;
}

/// Resolves the platform the application is currently running on.
abstract final class PlatformInfo {
  static AppPlatform get current {
    if (kIsWeb) return AppPlatform.other;
    try {
      if (Platform.isAndroid) return AppPlatform.android;
      if (Platform.isWindows) return AppPlatform.windows;
      if (Platform.isLinux) return AppPlatform.linux;
    } catch (_) {
      // Platform access can throw in some embedded contexts.
    }
    return AppPlatform.other;
  }

  /// Overridable for tests.
  static AppPlatform Function() resolver = _default;

  static AppPlatform _default() => current;
}

/// Convenience accessor that respects a test override.
AppPlatform currentPlatform() => PlatformInfo.resolver();
