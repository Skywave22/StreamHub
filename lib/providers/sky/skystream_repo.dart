import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/utils/json_util.dart';

/// Parsed "Enterprise V2" repository manifest as used by the SkyStream /
/// CloudStream ecosystem. Mirrors the public repository schema so short codes
/// and repository URLs genuinely resolve.
class SkyStreamRepo {
  const SkyStreamRepo({
    required this.name,
    required this.url,
    required this.manifestVersion,
    required this.pluginLists,
    required this.includedRepos,
    required this.pluginCount,
    this.packageName,
    this.description,
    this.iconUrl,
  });

  final String name;
  final String url;
  final String? packageName;
  final String? description;
  final String? iconUrl;
  final int manifestVersion;
  final List<String> pluginLists;
  final List<String> includedRepos;
  final int pluginCount;

  /// Stable id: explicit package name, else a hash of the URL.
  String get id =>
      packageName ??
      sha256.convert(utf8.encode(url)).toString().substring(0, 12);

  static bool looksLikeRepo(Map<String, dynamic> json) {
    final name = json['name'];
    final hasId = json['packageName'] != null || json['id'] != null;
    final pluginLists = asList(json, 'pluginLists');
    final repos = asList(json, 'repos');
    final plugins = asList(json, 'plugins');
    return name is String &&
        name.isNotEmpty &&
        hasId &&
        (pluginLists.isNotEmpty || repos.isNotEmpty || plugins.isNotEmpty);
  }

  /// Parses a repository manifest, or returns null when the document is not a
  /// valid repository manifest.
  static SkyStreamRepo? tryParse(Map<String, dynamic> json, String url) {
    if (!looksLikeRepo(json)) return null;
    final pluginLists = asList(json, 'pluginLists').whereType<String>().toList();
    final includedRepos = asList(json, 'repos').whereType<String>().toList();
    final plugins = asList(json, 'plugins');
    return SkyStreamRepo(
      name: asString(json, 'name') ?? 'Unknown repository',
      url: url,
      packageName: asString(json, 'packageName') ?? asString(json, 'id'),
      description: asString(json, 'description'),
      iconUrl: asString(json, 'iconUrl'),
      manifestVersion: asInt(json, 'manifestVersion') ?? 1,
      pluginLists: pluginLists,
      includedRepos: includedRepos,
      pluginCount: plugins.length + pluginLists.length,
    );
  }
}
