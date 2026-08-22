import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamhub/core/errors/app_exception.dart';
import 'package:streamhub/core/platform/platform_info.dart';
import 'package:streamhub/core/utils/checksum.dart';
import 'package:streamhub/providers/plugin_installer.dart';
import 'package:streamhub/providers/plugin_manifest.dart';
import 'package:streamhub/providers/provider.dart';
import 'package:streamhub/providers/provider_registry.dart';
import 'package:streamhub/providers/shortcode_resolver.dart';
import 'package:streamhub/providers/sky/skystream_repo.dart';
import 'package:streamhub/providers/url_validation.dart';

import 'test_helpers.dart';

void main() {
  group('ProviderRegistry', () {
    test('creates and caches provider instances', () {
      final registry = ProviderRegistry();
      registry.register('skystream', () => _DummyProvider('skystream'));
      expect(registry.contains('skystream'), isTrue);
      expect(identical(registry.create('skystream'), registry.create('skystream')), isTrue);
    });

    test('unknown id throws pluginNotFound', () {
      final registry = ProviderRegistry();
      expect(() => registry.create('nope'), throwsA(isA<AppException>()));
    });
  });

  group('PluginManifest', () {
    test('parses a valid manifest', () {
      final m = PluginManifest.fromJson({
        'id': 'com.example.plugin',
        'name': 'Example',
        'version': '1.2.3',
        'platforms': ['android'],
        'capabilities': {'search': true},
      }, sourceUrl: 'https://x/manifest.json');
      expect(m.id, 'com.example.plugin');
      expect(m.version, '1.2.3');
      expect(m.platforms, {ProviderPlatform.android});
      expect(m.capabilities.search, isTrue);
      expect(m.isCompatibleWith(AppPlatform.android), isTrue);
      expect(m.isCompatibleWith(AppPlatform.windows), isFalse);
    });

    test('defaults platforms to all three', () {
      final m = PluginManifest.fromJson({
        'id': 'a',
        'name': 'b',
        'version': '1.0.0',
      }, sourceUrl: 'x');
      expect(m.platforms, {ProviderPlatform.android, ProviderPlatform.windows, ProviderPlatform.linux});
    });

    test('rejects missing required fields', () {
      expect(
        () => PluginManifest.fromJson({'name': 'b', 'version': '1.0.0'}, sourceUrl: 'x'),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.manifestInvalid)),
      );
    });

    test('rejects invalid version', () {
      expect(
        () => PluginManifest.fromJson({'id': 'a', 'name': 'b', 'version': 'abc'}, sourceUrl: 'x'),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.manifestInvalid)),
      );
    });
  });

  group('UrlValidation', () {
    test('accepts https and rejects everything else', () {
      expect(UrlValidation.isValid('https://example.com/manifest.json'), isTrue);
      expect(UrlValidation.isValid('http://example.com/x'), isFalse);
      expect(UrlValidation.isValid('ftp://example.com/x'), isFalse);
      expect(UrlValidation.isValid(''), isFalse);
      expect(UrlValidation.isValid('not a url'), isFalse);
    });
  });

  group('ShortCodeResolver', () {
    test('validates code format', () {
      expect(ShortCodeResolver.isValidFormat('hexated'), isTrue);
      expect(ShortCodeResolver.isValidFormat('hex-ated_1'), isTrue);
      expect(ShortCodeResolver.isValidFormat('bad code'), isFalse);
      expect(ShortCodeResolver.isValidFormat(''), isFalse);
    });

    Future<ShortCodeResolver> resolver(Future<ResponseBody> Function(RequestOptions) handler) async {
      final adapter = FakeAdapter(handler);
      final api = fakeApi(adapter);
      return ShortCodeResolver(
        api: api,
        endpoint: 'https://fake.local/sky-',
        builtinFallback: const {'known': 'https://github.com/known/repo'},
      );
    }

    test('resolves a valid short code to a repository URL', () async {
      final r = await resolver((o) async {
        return ResponseBody.fromString('', 302, headers: {'location': ['https://github.com/known/repo']});
      });
      expect(await r.resolve('known'), 'https://github.com/known/repo');
    });

    test('throws invalidShortCode when the service returns its 404 page', () async {
      final r = await resolver((o) async {
        return ResponseBody.fromString('', 302, headers: {'location': ['https://cutt.ly/404']});
      });
      expect(
        () => r.resolve('bad'),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.invalidShortCode)),
      );
    });

    test('falls back to the built-in registry on network failure', () async {
      final r = await resolver((o) async {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });
      expect(await r.resolve('known'), 'https://github.com/known/repo');
    });

    test('rethrows network errors when no fallback exists', () async {
      final r = await resolver((o) async {
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      });
      expect(() => r.resolve('unknowncode'), throwsA(isA<AppException>()));
    });
  });

  group('PluginInstaller', () {
    test('installs a SkyStream repository from a URL', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('repo.json')) {
          return jsonBody({
            'name': 'Hexated',
            'packageName': 'com.hexated',
            'manifestVersion': 2,
            'pluginLists': ['https://x/list.json'],
          });
        }
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
      final outcome = await installer.install('https://fake.local/repo.json');
      expect(outcome.repo, isNotNull);
      expect(outcome.plugin.id, 'com.hexated');
      expect(outcome.plugin.config['type'], 'skystream-repository');
    });

    test('installs a generic plugin manifest', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('manifest.json')) {
          return jsonBody({
            'id': 'com.test.plugin',
            'name': 'Test Plugin',
            'version': '1.2.3',
            'platforms': ['android', 'windows', 'linux'],
          });
        }
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
      final outcome = await installer.install('https://fake.local/manifest.json');
      expect(outcome.manifest, isNotNull);
      expect(outcome.plugin.id, 'com.test.plugin');
    });

    test('verifies package checksum and fails on mismatch', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('manifest.json')) {
          return jsonBody({
            'id': 'com.test.plugin',
            'name': 'Test Plugin',
            'version': '1.0.0',
            'platforms': ['linux'],
            'packageUrl': 'https://fake.local/package.zip',
            'packageChecksum': 'deadbeef',
          });
        }
        if (o.path.contains('package.zip')) return textBody('package-bytes');
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
      expect(
        () => installer.install('https://fake.local/manifest.json'),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.checksumMismatch)),
      );
    });

    test('marks checksumVerified when the package matches', () async {
      final good = Checksum.sha256Hex('package-bytes');
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('manifest.json')) {
          return jsonBody({
            'id': 'com.test.plugin',
            'name': 'Test Plugin',
            'version': '1.0.0',
            'platforms': ['linux'],
            'packageUrl': 'https://fake.local/package.zip',
            'packageChecksum': good,
          });
        }
        if (o.path.contains('package.zip')) return textBody('package-bytes');
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
      final outcome = await installer.install('https://fake.local/manifest.json');
      expect(outcome.checksumVerified, isTrue);
    });

    test('rejects plugins incompatible with the current platform', () async {
      final adapter = FakeAdapter((o) async {
        return jsonBody({
          'id': 'com.test.plugin',
          'name': 'Android only',
          'version': '1.0.0',
          'platforms': ['android'],
        });
      });
      final api = fakeApi(adapter);
      final installer = PluginInstaller(api: api, shortCodes: ShortCodeResolver(api: api));
      expect(
        () => installer.install('https://fake.local/manifest.json', platform: AppPlatform.linux),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.pluginIncompatible)),
      );
    });

    test('resolves a short code end-to-end into a repository plugin', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('sky-hexated')) {
          return ResponseBody.fromString('', 302, headers: {'location': ['https://fake.local/repo.json']});
        }
        if (o.path.contains('repo.json')) {
          return jsonBody({'name': 'Hexated', 'packageName': 'com.hexated', 'pluginLists': ['x']});
        }
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final shortCodes = ShortCodeResolver(api: api, endpoint: 'https://fake.local/sky-');
      final installer = PluginInstaller(api: api, shortCodes: shortCodes);
      final outcome = await installer.install('hexated');
      expect(outcome.repo, isNotNull);
      expect(outcome.plugin.id, 'com.hexated');
    });
  });

  group('SkyStreamRepo', () {
    test('looksLikeRepo detects the Enterprise V2 shape', () {
      expect(
        SkyStreamRepo.looksLikeRepo({'name': 'X', 'packageName': 'com.x', 'pluginLists': ['a']}),
        isTrue,
      );
      expect(SkyStreamRepo.looksLikeRepo({'id': 'a', 'name': 'b', 'version': '1.0.0'}), isFalse);
    });
  });

  group('PluginManager', () {
    test('seeds bundled providers and gates CloudStream to Android', () async {
      final h = await buildHarness();
      final plugins = h.pluginManager.list();
      expect(plugins.length, 3);
      final linux = h.pluginManager.visibleOn(AppPlatform.linux).map((p) => p.id).toSet();
      expect(linux, {'skystream', 'nuvio'});
      expect(linux.contains('cloudstream'), isFalse);
      final android = h.pluginManager.visibleOn(AppPlatform.android).map((p) => p.id).toSet();
      expect(android, {'skystream', 'nuvio', 'cloudstream'});
      final activeProviders = h.pluginManager.activeProviders(AppPlatform.linux);
      expect(activeProviders.length, 2);
    });

    test('enables/disables providers', () async {
      final h = await buildHarness();
      await h.pluginManager.setEnabled('skystream', false);
      expect(h.pluginManager.byId('skystream')!.enabled, isFalse);
      expect(h.pluginManager.active(AppPlatform.linux).length, 1);
      await h.pluginManager.setEnabled('skystream', true);
      expect(h.pluginManager.active(AppPlatform.linux).length, 2);
    });

    test('configure() adds direct sources that getSources returns', () async {
      final h = await buildHarness();
      await h.pluginManager.configure('skystream', {
        'directSources': [
          {'name': 'Sample', 'url': 'https://example.com/v.mp4', 'quality': '1080p'},
        ],
      });
      final provider = h.pluginManager.provider('skystream')!;
      final sources = await provider.getSources('tmdb:550');
      expect(sources.length, 1);
      expect(sources.first.providerId, 'skystream');
      expect(sources.first.quality, '1080p');
    });

    test('remove() deletes a provider record', () async {
      final h = await buildHarness();
      await h.pluginManager.remove('nuvio');
      expect(h.pluginManager.byId('nuvio'), isNull);
      expect(h.pluginManager.list().length, 2);
    });
  });
}

class _DummyProvider extends StreamProvider {
  _DummyProvider(this.id);
  @override
  final String id;

  @override
  String get name => 'Dummy';
  @override
  String get version => '1.0.0';
  @override
  String get description => 'dummy';
  @override
  Set<ProviderPlatform> get supportedPlatforms => const {ProviderPlatform.android};
  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities();
}
