# StreamHub

A fast, modern cross-platform streaming application for **Android**, **Windows**
and **Linux** with a real, modular provider/plugin architecture and a
SkyStream-green theme.

StreamHub runs actual third-party plugins: **SkyStream/CloudStream JavaScript
extensions** (in an isolated QuickJS engine) and **Nuvio/Stremio addons** (JSON
protocol). TMDB supplies metadata. No DRM, authentication, subscription,
licensing or access control is ever bypassed.

## Supported platforms

| Platform | SkyStream | Nuvio | CloudStream |
|----------|-----------|-------|-------------|
| Android  | ✅        | ✅    | ✅          |
| Windows  | ✅        | ✅    | ❌ (Android-only) |
| Linux    | ✅        | ✅    | ❌ (Android-only) |

Providers that are unsupported on the current platform are automatically hidden.

## Features

- **Real plugin engine** — SkyStream/CloudStream JS extensions run in an
  isolated QuickJS runtime (`flutter_js`) with the standard extension SDK
  (`app.get/post/head`, `parseHtml`, `MultimediaItem`, `StreamResult`,
  `getPreference/setPreference`). Repositories are added by **short code** or
  URL, then extensions are installed/enabled/disabled/updated/removed.
- **Real addon engine** — Nuvio/Stremio-compatible addons (`manifest.json`,
  `transportUrl`, catalogs, `/catalog|/meta|/stream`) stream content directly.
- **Home** — Continue Watching, Trending, Popular Movies, Popular TV, New
  Releases, Favorites, Watchlist, Recently Watched and Recommendations.
- **Search** — global, debounced search across every enabled provider with
  filters for type, provider, year and genre.
- **Media details** — poster, backdrop, cast, genres, ratings, overview,
  trailers, similar titles, seasons, episodes and provider availability.
- **Library** — Favorites, Watchlist, Watched and Continue Watching.
- **Player** — media_kit (libmpv): play/pause, seek, fullscreen, volume, speed,
  subtitles, audio tracks, buffering, retry, next/previous episode, autoplay
  countdown and resume.
- **Source selection** — Auto / Highest quality / Fastest / Manual, with real
  reachability verification before a source is marked playable.
- **Performance** — async I/O, image/metadata/HTTP caching, request
  deduplication, debounce, cancellation and pagination.
- **SkyStream-green theme** — dark/light/system with an emerald accent.

## Architecture

```
lib/
├── core/                  # platform info, networking, caching, storage, models
├── providers/
│   ├── provider.dart      # common StreamProvider contract
│   ├── plugin_manager.dart # bundled providers + contributed providers
│   ├── extensions/        # REAL repository + extension engine
│   │   ├── repository_service.dart   # short codes, repos, plugin lists
│   │   ├── extension_manager.dart    # install/enable/disable/update/remove
│   │   ├── extension_models.dart     # Repository / SitePlugin / InstalledExtension
│   │   ├── js/extension_runner.dart  # QuickJS runtime + Dart bridge
│   │   ├── js/sdk_shim.dart          # the JS SDK surface extensions use
│   │   └── js_extension_provider.dart# StreamProvider backed by a JS extension
│   └── addons/            # REAL Stremio/Nuvio addon engine
│       ├── addon_models.dart  # AddonManifest / ManagedAddon
│       ├── addon_service.dart # /catalog /meta /stream
│       └── addon_provider.dart
├── services/              # TMDB, search, playback, source resolver
└── ui/                    # screens, widgets, theme, router
```

### The provider contract

```dart
abstract class StreamProvider {
  String get id;
  String get name;
  String get version;
  Set<ProviderPlatform> get supportedPlatforms;
  ProviderCapabilities get capabilities;

  Future<List<MediaItem>> search(String query, {SearchFilter? filter, int page = 1});
  Future<MediaDetails?> getDetails(String mediaId);
  Future<List<Season>> getSeasons(String mediaId);
  Future<List<Episode>> getEpisodes(String mediaId, int seasonNumber);
  Future<List<MediaSource>> getSources(String mediaId, {int? season, int? episode});
  Future<MediaSource> resolveSource(MediaSource source);
}
```

### How plugins really run

1. **Add a repository** (`Settings → Plugins → Add`) by SkyStream short code
   (e.g. `hexated`) or HTTPS URL. Short codes resolve through the same
   public mechanism SkyStream uses; repositories use the "Enterprise V2"
   schema (`name`, `packageName`, `pluginLists`, `plugins`).
2. **Browse & install** extensions from the repository. Each extension is a JS
   file; its SHA-256 is verified when the repository declares one.
3. **Search / Play.** Enabled extensions are first-class providers: search runs
   `search(query, cb)`, details run `load(url, cb)`, sources run
   `loadStreams(url, cb)` inside QuickJS, and every returned stream URL is
   probed before it is marked playable.
4. **Addons** (`manifest.json` URLs) provide catalogs, metadata and streams via
   the Stremio protocol.

## TMDB configuration

`Settings → TMDB` — enter your own key (from themoviedb.org), test it, remove
it. The key is stored in the platform keychain/keystore and never logged or
committed. TMDB powers metadata rows and metadata search.

## Getting started

- Flutter 3.47+ (Dart 3.13+)
- Android: JDK 17+, Android SDK
- Linux: `clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev libsecret-1-dev libjsoncpp-dev`
- Windows: Visual Studio 2022 (Desktop development with C++)

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release          # Android APK
flutter build appbundle --release    # Android AAB
flutter build linux --release        # Linux
flutter build windows --release      # Windows
```

## Security

- HTTPS only; timeouts, retries with exponential backoff and cancellation.
- Extension JavaScript runs in an isolated QuickJS runtime; the core app never
  executes downloaded code natively.
- Plugin checksums are verified when declared.
- Secrets are never logged or committed; no access control is bypassed.

## Known limitations

- Extensions are third-party code run in a sandbox; behaviour depends on the
  plugin author. `crypto.decryptAES`/`pbkdf2` and captcha solving are not
  implemented and fail loudly.
- DOM `select()` support covers the most common selectors; very complex
  jsoup queries may not match.
- SkyStream short codes require the provider's short-code service to be
  reachable.
- Desktop builds are per-OS; CI builds Windows on Windows runners.

## Contributing

PRs welcome. Keep provider integrations behind the `StreamProvider` /
`ProviderSourceEngine` boundaries and never commit credentials.

## License

GPL-3.0 — see [LICENSE](LICENSE) and [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
