import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemePreference { system, dark, light }

enum UiDensity { comfortable, compact }

enum SourceSelectionMode { auto, highestQuality, fastest, manual }

/// User settings backed by [SharedPreferences]. Reacts to changes so the UI
/// can update live. The TMDB API key is intentionally NOT stored here — it
/// lives in [SecureStorage].
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const kTheme = 'settings.theme';
  static const kAccent = 'settings.accent';
  static const kDensity = 'settings.density';
  static const kLanguage = 'settings.language';
  static const kDefaultQuality = 'settings.defaultQuality';
  static const kAutoplayNext = 'settings.autoplayNext';
  static const kSubtitles = 'settings.subtitles';
  static const kAudioLanguage = 'settings.audioLanguage';
  static const kResumePlayback = 'settings.resumePlayback';
  static const kPlaybackSpeed = 'settings.playbackSpeed';
  static const kSourceMode = 'settings.sourceMode';

  ThemePreference get themePreference =>
      ThemePreference.values.asNameMap()[_prefs.getString(kTheme)] ?? ThemePreference.system;
  set themePreference(ThemePreference v) => _set(kTheme, v.name);

  int get accentColor => _prefs.getInt(kAccent) ?? 0xFF10B981; // SkyStream green
  set accentColor(int v) => _setInt(kAccent, v);

  UiDensity get density => UiDensity.values.asNameMap()[_prefs.getString(kDensity)] ?? UiDensity.comfortable;
  set density(UiDensity v) => _set(kDensity, v.name);

  String get language => _prefs.getString(kLanguage) ?? 'en';
  set language(String v) => _set(kLanguage, v);

  String get defaultQuality => _prefs.getString(kDefaultQuality) ?? 'Auto';
  set defaultQuality(String v) => _set(kDefaultQuality, v);

  bool get autoplayNext => _prefs.getBool(kAutoplayNext) ?? true;
  set autoplayNext(bool v) => _setBool(kAutoplayNext, v);

  bool get subtitlesEnabled => _prefs.getBool(kSubtitles) ?? false;
  set subtitlesEnabled(bool v) => _setBool(kSubtitles, v);

  String get audioLanguage => _prefs.getString(kAudioLanguage) ?? 'Original';
  set audioLanguage(String v) => _set(kAudioLanguage, v);

  bool get resumePlayback => _prefs.getBool(kResumePlayback) ?? true;
  set resumePlayback(bool v) => _setBool(kResumePlayback, v);

  double get playbackSpeed => _prefs.getDouble(kPlaybackSpeed) ?? 1.0;
  set playbackSpeed(double v) => _setDouble(kPlaybackSpeed, v);

  SourceSelectionMode get sourceSelectionMode =>
      SourceSelectionMode.values.asNameMap()[_prefs.getString(kSourceMode)] ?? SourceSelectionMode.auto;
  set sourceSelectionMode(SourceSelectionMode v) => _set(kSourceMode, v.name);

  void _set(String key, String value) {
    _prefs.setString(key, value);
    notifyListeners();
  }

  void _setInt(String key, int value) {
    _prefs.setInt(key, value);
    notifyListeners();
  }

  void _setBool(String key, bool value) {
    _prefs.setBool(key, value);
    notifyListeners();
  }

  void _setDouble(String key, double value) {
    _prefs.setDouble(key, value);
    notifyListeners();
  }
}
