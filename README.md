# StreamHub

A fast, modern cross-platform streaming application for **Android**, **Windows** and
**Linux**, built around a modular provider/plugin architecture.

StreamHub is a media client shell: it aggregates metadata (via **TMDB**) and lets you
install providers/plugins — **SkyStream**, **Nuvio** and **CloudStream** — independently
of the core app. The core application never bundles scraping logic and never bypasses
DRM, authentication, subscriptions, licensing or access controls.

---

## Supported platforms

| Platform | SkyStream | Nuvio | CloudStream |
|----------|-----------|-------|-------------|
| Android  | ✅        | ✅    | ✅          |
| Windows  | ✅        | ✅    | ❌ (Android-only) |
| Linux    | ✅        | ✅    | ❌ (Android-only) |

Providers that are unsupported on the current platform are **automatically hidden**.

## Features

- **Home** — Continue Watching, Trending, Popular Movies, Popular TV, New Releases,
  Favorites, Watchlist, Recently Watched and Recommendations (lazy-loaded + cached).
- **Search** — global, debounced search across all active providers with filters for
  type, provider, year and genre.
- **Media details** — poster, backdrop, cast, crew, genres, ratings, overview,
  trailers (via YouTube), similar titles, seasons, episodes and provider availability.
- **Library** — Favorites, Watchlist, Watched and Continue Watching in a local database.
- **Continue Watching** — persists position/duration and resumes automatically.
- **Player** — play/pause, seek, fullscreen, volume, speed, subtitles, audio tracks,
  buffering, retry, next/previous episode and an autoplay countdown (can be disabled).
- **Source selection** — Auto / Highest quality / Fastest / Manual, with real
  reachability verification before a source is marked playable.
- **Plugin manager** — install, enable, disable, update, reload, remove, configure and
  inspect providers, plus an activity log.
- **Settings** — TMDB, playback, plugins, appearance, storage and network.
- **Performance** — async I/O, image/metadata/HTTP caching, request deduplication,
  debounce, cancellation, pagination and minimal startup work.

---

## Architecture

```
lib/
├── core/            # platform info, networking, caching, storage, models, errors
├── providers/       # provider interface, plugin manager, installers, integrations
│   ├── provider.dart            # common provider contract
│   ├── plugin_manager.dart      # lifecycle (install/enable/disable/update/…)
│   ├── plugin_installer.dart    # raw URL + short code installation
│   ├── shortcode_resolver.dart  # SkyStream short-code resolution
│   ├── source_engine.dart       # isolated source discovery/resolution boundary
│   └── integrations/            # SkyStream, Nuvio, CloudStream adapters
├── services/        # TMDB, search, playback controller, source resolver
└── ui/              # screens, widgets, theme, router
```

### Provider interface

Every provider implements a common contract — the core app depends only on it, never on
a concrete provider:

```dart
abstract class StreamProvider {
  String get id;
  String get name;
  String get version;
  String get description;
  Set<ProviderPlatform> get supportedPlatforms;
  ProviderCapabilities get capabilities;

  Future<void> initialize();
  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1});
  Future<MediaDetails?> getDetails(String mediaId);
  Future<List<Season>> getSeasons(String mediaId);
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber);
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode});
  Future<MediaSource> resolveSource(MediaSource source);
  Future<void> shutdown();
}
```

Adding a new provider means registering a factory in the `ProviderRegistry` — no core
changes are required.

### Providers

- **SkyStream** — metadata via TMDB; sources via installed SkyStream repositories.
  SkyStream **short codes** are resolved through the same public mechanism the SkyStream
  app uses (a URL-shortener prefix that redirects to the repository URL). Invalid short
  codes are rejected gracefully — short codes are never fabricated.
- **Nuvio** — metadata via TMDB; sources via Nuvio plugins installed from a raw HTTPS
  plugin URL.
- **CloudStream** — Android only; integrates through CloudStream's legitimate
  extension-repository architecture. It is hidden on Windows/Linux.

The native scraping engine behind each provider is an **isolated integration point**
(`ProviderSourceEngine`). The core app never executes downloaded plugin code; sources are
only marked *verified* after an actual reachability probe.

### Raw plugin URL system

`Settings → Plugins → Add Plugin` accepts a legitimate HTTPS plugin URL or a SkyStream
short code and performs: URL validation → manifest discovery → metadata parse → version
detection → compatibility checks → **checksum verification (when declared)** → install.
Installed plugins can then be enabled, disabled, updated, reloaded, removed and
configured.

---

## TMDB configuration

`Settings → TMDB` lets you enter **your own** TMDB API key (from
[themoviedb.org](https://www.themoviedb.org/)), test it, and remove it. The key:

- is stored securely (platform keychain/keystore via `flutter_secure_storage`),
- is never hard-coded, logged, or committed.

Without a key the app still works, but metadata rows prompt you to configure TMDB.

---

## Getting started

### Requirements

- Flutter 3.47+ (Dart 3.13+)
- Android: JDK 17+, Android SDK
- Linux: `clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev libsecret-1-dev libjsoncpp-dev`
- Windows: Visual Studio 2022 (Desktop development with C++)

### Development

```bash
flutter pub get
flutter run            # run on the connected device/desktop
flutter analyze        # lint
flutter test           # unit tests
```

### Build

```bash
flutter build apk --release          # Android (APK)
flutter build appbundle --release    # Android (AAB)
flutter build windows --release      # Windows (exe + bundle)
flutter build linux --release        # Linux (bundle)
```

Release artifacts (plus SHA-256 checksums) are produced by the CI workflow in
`.github/workflows/ci.yml` and can also be generated with `scripts/package.sh`.

---

## Security

- HTTPS only; timeouts, retries with exponential backoff and cancellation.
- Secrets (TMDB key, tokens) are **never** logged or committed; debug logging redacts
  query strings.
- Plugins are validated (manifests, checksums when available) and **never executed** by
  the core app.
- No DRM, authentication, subscription, licensing or access control is bypassed.

## Known limitations

- Provider source engines are isolated integration points: StreamHub ships the adapter,
  plugin manager and verification pipeline, but not the third-party scraping engines
  themselves.
- SkyStream short codes rely on the provider's short-code service being reachable.
- Desktop builds are packaged per-OS; Windows builds are produced on Windows CI runners.

## Contributing

Issues and pull requests are welcome. Please keep provider integrations behind the
`ProviderSourceEngine` boundary and never commit credentials.

## License

GPL-3.0 — see [LICENSE](LICENSE). Third-party dependencies and provider integrations
retain their own licenses; this project does not claim ownership of any third-party
software.
