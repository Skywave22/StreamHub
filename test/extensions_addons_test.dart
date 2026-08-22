
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamhub/core/errors/app_exception.dart';
import 'package:streamhub/core/utils/checksum.dart';
import 'package:streamhub/providers/addons/addon_models.dart';
import 'package:streamhub/providers/addons/addon_provider.dart';
import 'package:streamhub/providers/addons/addon_service.dart';
import 'package:streamhub/providers/extensions/extension_manager.dart';
import 'package:streamhub/providers/extensions/extension_models.dart';
import 'package:streamhub/providers/extensions/js/extension_runner.dart';
import 'package:streamhub/providers/extensions/js_extension_provider.dart';
import 'package:streamhub/providers/extensions/repository_service.dart';

import 'test_helpers.dart';

// ---- fake JS runner (no flutter_js needed in tests) ------------------------

class FakeRunner implements ExtensionRunner {
  FakeRunner(this.handlers);
  final Map<String, dynamic Function(List<dynamic>?)> handlers;
  int initCount = 0;

  @override
  Future<void> init() async => initCount++;

  @override
  Future<dynamic> invoke(String fnName, [List<dynamic>? args]) async {
    final h = handlers[fnName];
    return h?.call(args);
  }

  @override
  void dispose() {}
}

final repoJson = {
  'name': 'Hexated',
  'packageName': 'com.hexated',
  'manifestVersion': 2,
  'pluginLists': ['https://cdn.jsdelivr.net/gh/hexated/repo@list.json'],
};

final pluginListDoc = {
  'Hexated': [
    {
      'url': 'https://cdn.jsdelivr.net/gh/hexated/repo@SuperStream.cs3',
      'name': 'SuperStream',
      'internalName': 'com.hexated.superstream',
      'version': 3,
      'status': 1,
      'authors': ['Hexated'],
      'language': 'en',
    },
    {
      'url': 'https://cdn.jsdelivr.net/gh/hexated/repo@Other.cs3',
      'name': 'Other',
      'internalName': 'com.hexated.other',
      'version': 1,
    },
  ],
};

const fakeExtensionCode = '(function(){ globalThis.search = function(q, cb){ cb({success:true, data: []}); }; })();';

void main() {
  group('ExtensionRepository parsing', () {
    test('parses the Enterprise V2 schema', () {
      expect(ExtensionRepository.looksLike(repoJson), isTrue);
      final repo = ExtensionRepository.fromJson(repoJson, 'https://x');
      expect(repo.id, 'com.hexated');
      expect(repo.manifestVersion, 2);
      expect(repo.pluginLists.length, 1);
    });

    test('parses inline plugins', () {
      final repo = ExtensionRepository.fromJson({
        'name': 'X',
        'id': 'com.x',
        'plugins': [
          {'url': 'https://x/a.cs3', 'name': 'A', 'internalName': 'com.x.a', 'version': 2},
        ],
      }, 'https://x');
      expect(repo.inlinePlugins.length, 1);
      expect(repo.inlinePlugins.first.packageName, 'com.x.a');
    });
  });

  group('parsePluginListDocument', () {
    test('flattens grouped plugin lists', () {
      final plugins = parsePluginListDocument(pluginListDoc, repositoryUrl: 'x');
      expect(plugins.length, 2);
      expect(plugins.first.packageName, 'com.hexated.superstream');
    });

    test('handles a plain list', () {
      final plugins = parsePluginListDocument([
        {'url': 'https://x/a.cs3', 'name': 'A', 'internalName': 'com.x.a'},
      ], repositoryUrl: 'x');
      expect(plugins.length, 1);
    });
  });

  group('RepositoryService', () {
    RepositoryService service(FakeAdapter adapter) => RepositoryService(api: fakeApi(adapter));

    test('normalizes raw github URLs to jsDelivr', () {
      final s = service(FakeAdapter((o) async => jsonBody({})));
      expect(
        s.normalizeUrl('https://raw.githubusercontent.com/hexated/repo/master/list.json'),
        'https://cdn.jsdelivr.net/gh/hexated/repo@master/list.json',
      );
    });

    test('resolves a SkyStream short code through cutt.ly', () async {
      final s = service(FakeAdapter((o) async {
        if (o.path.contains('sky-hexated')) {
          return ResponseBody.fromString('', 302, headers: {'location': ['https://github.com/hexated/repo']});
        }
        return jsonBody({});
      }));
      expect(await s.resolveUrl('hexated'), 'https://github.com/hexated/repo');
    });

    test('rejects an invalid short code', () async {
      final s = service(FakeAdapter((o) async {
        return ResponseBody.fromString('', 302, headers: {'location': ['https://cutt.ly/404']});
      }));
      expect(() => s.resolveUrl('nope'), throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.invalidShortCode)));
    });

    test('fetches and validates a repository', () async {
      final s = service(FakeAdapter((o) async {
        if (o.path.contains('repo.json')) return jsonBody(repoJson);
        return jsonBody({}, 404);
      }));
      final repo = await s.fetchRepository('https://fake/repo.json');
      expect(repo.id, 'com.hexated');
    });

    test('downloads plugin code and verifies sha256', () async {
      final good = Checksum.sha256Hex('the-plugin-code');
      final s = service(FakeAdapter((o) async {
        if (o.path.contains('plugin')) return textBody('the-plugin-code');
        return jsonBody({}, 404);
      }));
      final plugin = SitePlugin.fromJson({
        'url': 'https://fake/plugin.cs3',
        'name': 'P',
        'internalName': 'com.x.p',
        'version': 1,
        'fileHash': 'sha256-$good',
      });
      expect(await s.downloadPluginCode(plugin), 'the-plugin-code');
    });

    test('rejects a plugin whose checksum does not match', () async {
      final s = service(FakeAdapter((o) async {
        if (o.path.contains('plugin')) return textBody('tampered');
        return jsonBody({}, 404);
      }));
      final plugin = SitePlugin.fromJson({
        'url': 'https://fake/plugin.cs3',
        'name': 'P',
        'internalName': 'com.x.p',
        'version': 1,
        'fileHash': 'sha256-${Checksum.sha256Hex('original')}',
      });
      expect(
        () => s.downloadPluginCode(plugin),
        throwsA(predicate((e) => e is AppException && e.kind == AppErrorKind.checksumMismatch)),
      );
    });
  });

  group('ExtensionManager lifecycle', () {
    Future<ExtensionManager> manager(FakeAdapter adapter) async {
      final service = RepositoryService(api: fakeApi(adapter));
      return ExtensionManager(
        repoBox: await openBox(),
        pluginBox: await openBox(),
        dataBox: await openBox(),
        repositoryService: service,
        api: fakeApi(FakeAdapter((o) async => textBody('', 206))),
      );
    }

    test('adds a repository, installs and manages an extension', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('repo.json')) return jsonBody(repoJson);
        if (o.path.contains('list.json')) return jsonBody(pluginListDoc);
        if (o.path.contains('cs3')) return textBody(fakeExtensionCode);
        return jsonBody({}, 404);
      });
      final em = await manager(adapter);

      final repo = await em.addRepository('https://fake/repo.json');
      expect(em.repositories.length, 1);
      expect(repo.id, 'com.hexated');

      final plugins = await em.pluginsFor(repo);
      expect(plugins.length, 2);

      final installed = await em.install(plugins.first, repo.url);
      expect(installed.packageName, 'com.hexated.superstream');
      expect(em.installed.length, 1);
      expect(em.extensionById('com.hexated.superstream')!.code, fakeExtensionCode);

      // Contributed providers expose the extension with its namespaced id.
      final providers = em.enabledProviders();
      expect(providers.length, 1);
      expect(providers.first.id, 'ext:com.hexated.superstream');

      await em.setEnabled('com.hexated.superstream', false);
      expect(em.enabledProviders(), isEmpty);

      await em.uninstall('com.hexated.superstream');
      expect(em.installed, isEmpty);
    });
  });

  group('JsExtensionProvider (fake runner)', () {
    InstalledExtension extension({String code = fakeExtensionCode}) => InstalledExtension(
          packageName: 'com.hexated.superstream',
          name: 'SuperStream',
          version: 3,
          repositoryUrl: 'https://fake',
          fileUrl: 'https://fake/s.cs3',
          code: code,
        );

    Future<JsExtensionProvider> provider(FakeRunner runner) async {
      final api = fakeApi(FakeAdapter((o) async => textBody('', 206)));
      final p = JsExtensionProvider(
        extension: extension(),
        runnerFactory: () => runner,
        api: api,
      );
      return p;
    }

    test('maps search results to MediaItems', () async {
      final runner = FakeRunner({
        'search': (args) => {
              'success': true,
              'data': [
                {
                  'title': 'Example Movie',
                  'url': 'https://example.com/movie',
                  'posterUrl': 'https://example.com/p.jpg',
                  'type': 'movie',
                },
              ],
            },
      });
      final p = await provider(runner);
      final items = await p.search('example');
      expect(items.length, 1);
      expect(items.first.title, 'Example Movie');
      expect(items.first.id, startsWith('ext:com.hexated.superstream:'));
    });

    test('maps loadStreams results to MediaSources', () async {
      final runner = FakeRunner({
        'loadStreams': (args) => {
              'success': true,
              'data': [
                {'url': 'https://cdn.example.com/v.m3u8', 'source': '1080p'},
              ],
            },
      });
      final p = await provider(runner);
      final id = JsExtensionProvider.mediaIdFor('com.hexated.superstream', 'https://example.com/movie');
      final sources = await p.getSources(id);
      expect(sources.length, 1);
      expect(sources.first.url, 'https://cdn.example.com/v.m3u8');
      expect(sources.first.providerId, 'ext:com.hexated.superstream');
      expect(sources.first.quality, '1080p');
    });

    test('maps load results to MediaDetails with episodes', () async {
      final runner = FakeRunner({
        'load': (args) => {
              'success': true,
              'data': {
                'title': 'Example Show',
                'url': 'https://example.com/show',
                'type': 'series',
                'episodes': [
                  {'season': 1, 'episode': 1, 'title': 'Pilot'},
                  {'season': 1, 'episode': 2, 'title': 'Second'},
                ],
              },
            },
      });
      final p = await provider(runner);
      final id = JsExtensionProvider.mediaIdFor('com.hexated.superstream', 'https://example.com/show');
      final details = await p.getDetails(id);
      expect(details, isNotNull);
      expect(details!.episodes.length, 2);
      expect(details.seasons.length, 1);
    });
  });

  group('Addon system (Stremio/Nuvio)', () {
    final manifestJson = {
      'id': 'org.example.addon',
      'name': 'Example Addon',
      'version': '1.0.0',
      'transportUrl': 'https://addon.example/',
      'resources': ['catalog', 'meta', 'stream'],
      'types': ['movie', 'series'],
      'catalogs': [
        {'type': 'movie', 'id': 'top', 'name': 'Top'},
      ],
    };

    test('parses an addon manifest', () {
      final m = AddonManifest.fromJson(manifestJson, sourceUrl: 'https://addon.example/manifest.json');
      expect(m.id, 'org.example.addon');
      expect(m.baseUrl('https://addon.example/manifest.json'), 'https://addon.example/');
    });

    test('searches catalogs and resolves streams', () async {
      final adapter = FakeAdapter((o) async {
        if (o.path.contains('/catalog/')) {
          return jsonBody({
            'metas': [
              {'id': 'tt123', 'type': 'movie', 'name': 'A Good Movie', 'poster': 'https://x/p.jpg', 'year': '2024'},
            ],
          });
        }
        if (o.path.contains('/stream/')) {
          return jsonBody({
            'streams': [
              {'url': 'https://cdn.example.com/movie.mp4', 'title': '720p'},
            ],
          });
        }
        return jsonBody({}, 404);
      });
      final api = fakeApi(adapter);
      final service = AddonService(api: api);
      final addon = ManagedAddon(
        manifestUrl: 'https://addon.example/manifest.json',
        manifest: AddonManifest.fromJson(manifestJson, sourceUrl: 'https://addon.example/manifest.json'),
        enabled: true,
      );
      final provider = AddonProvider(addon: addon, service: service, api: api);

      final results = await provider.search('good');
      expect(results.length, 1);
      expect(results.first.title, 'A Good Movie');
      expect(results.first.id, startsWith('addon:org.example.addon:movie:'));

      final sources = await provider.getSources(results.first.id);
      expect(sources.length, 1);
      expect(sources.first.url, 'https://cdn.example.com/movie.mp4');
      expect(sources.first.providerId, 'addon:org.example.addon');
    });
  });
}
