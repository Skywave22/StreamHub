# Third-Party Notices

StreamHub implements **compatible open interfaces and formats**, and integrates
third-party open-source software. No third-party source code is vendored into
this repository; this file documents the projects whose public interfaces,
formats and protocols StreamHub interoperates with, and the open-source
libraries StreamHub depends on.

## Provider / plugin ecosystems (interoperability)

- **CloudStream** (https://github.com/recloudstream/cloudstream) — GPL-3.0.
  StreamHub implements the same repository/extension *formats* (repository
  manifests, plugin lists, `.cs3`-style JS extensions) so CloudStream-compatible
  repositories can be loaded. StreamHub is not affiliated with CloudStream and
  contains no CloudStream code.
- **SkyStream** (https://github.com/akashdh11/skystream) — GPL-3.0.
  StreamHub implements the SkyStream-compatible extension SDK surface
  (`MultimediaItem`, `StreamResult`, `getHome`/`search`/`load`/`loadStreams`,
  `app.get/post/head`, `parseHtml`) and the SkyStream short-code mechanism so
  SkyStream-compatible plugins can run. StreamHub contains no SkyStream code.
- **Nuvio** (https://github.com/NuvioMedia/NuvioMobile) — StreamHub implements
  the Stremio-compatible addon manifest protocol that Nuvio addons use
  (`manifest.json` with `transportUrl`, `catalogs`, `types`, `idPrefixes`, and
  `/catalog|/meta|/stream` endpoints).

## Runtime dependencies (via pub)

| Package | Purpose | License |
|---------|---------|---------|
| flutter | Flutter SDK | BSD-3-Clause |
| flutter_riverpod | State management | MIT |
| go_router | Navigation | BSD-3-Clause |
| dio | HTTP client | MIT |
| flutter_js | QuickJS JavaScript runtime (extension engine) | MIT |
| hive / hive_flutter | Local database | Apache-2.0 |
| shared_preferences | Settings storage | BSD-3-Clause |
| flutter_secure_storage | Credential storage | BSD-3-Clause |
| cached_network_image | Image caching | MIT |
| media_kit (+video) | Playback (libmpv) | MIT |
| html | HTML parsing (extension DOM bridge) | MIT |
| url_launcher / package_info_plus / wakelock_plus | Platform utilities | BSD-3-Clause |
| crypto | Hashing | BSD-3-Clause |

Full license texts for these dependencies are available in each package's
repository. `libmpv` is used for playback via media_kit and is LGPL-2.1+ /
GPL-2.0+ — refer to media_kit's documentation for compliance details.

## Security note

- Extensions are third-party JavaScript. StreamHub runs them in an isolated
  QuickJS runtime and never executes downloaded code outside that sandbox.
- StreamHub never bypasses DRM, authentication, subscriptions, licensing or
  access controls, and does not redistribute any provider's extension code.
