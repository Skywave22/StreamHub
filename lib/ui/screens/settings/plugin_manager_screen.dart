import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/providers.dart';
import '../../../providers/addons/addon_models.dart';
import '../../../providers/extensions/extension_manager.dart';
import '../../../providers/extensions/extension_models.dart';
import '../../../providers/provider.dart';

class PluginManagerScreen extends ConsumerWidget {
  const PluginManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = ref.watch(pluginManagerProvider);
    final em = ref.watch(extensionManagerProvider);
    final am = ref.watch(addonManagerProvider);
    final bundled = pm.visibleOn(currentPlatform());

    return Scaffold(
      appBar: AppBar(title: const Text('Plugins', style: TextStyle(fontWeight: FontWeight.w700))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/plugins/add'),
        icon: const Icon(Icons.add),
        label: const Text('Add plugin'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          _header(context, 'Repositories'),
          if (em.repositories.isEmpty)
            const _Hint(text: 'Add a SkyStream/CloudStream repository by short code or URL to install extensions.')
          else
            for (final repo in em.repositories) _RepoCard(repo: repo),
          const SizedBox(height: 16),
          _header(context, 'Installed extensions'),
          if (em.installed.isEmpty)
            const _Hint(text: 'No extensions installed yet. Add a repository and install its plugins.')
          else
            for (final ext in em.installed) _ExtensionCard(extension: ext),
          const SizedBox(height: 16),
          _header(context, 'Addons (Stremio/Nuvio)'),
          if (am.addons.isEmpty)
            const _Hint(text: 'Add a Stremio-compatible addon manifest URL to stream from it.')
          else
            for (final addon in am.addons) _AddonCard(addon: addon),
          const SizedBox(height: 16),
          _header(context, 'Built-in providers'),
          for (final plugin in bundled) _BundledCard(plugin: plugin),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 6),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _RepoCard extends ConsumerStatefulWidget {
  const _RepoCard({required this.repo});
  final ExtensionRepository repo;

  @override
  ConsumerState<_RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends ConsumerState<_RepoCard> {
  bool _expanded = false;
  bool _loading = false;
  List<SitePlugin> _plugins = const [];
  String? _error;

  Future<void> _browse() async {
    setState(() {
      _expanded = !_expanded;
      if (_expanded && _plugins.isEmpty) _loading = true;
    });
    if (_expanded) {
      try {
        final em = ref.read(extensionManagerProvider);
        final plugins = await em.pluginsFor(widget.repo);
        if (!mounted) return;
        setState(() {
          _plugins = plugins;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load plugins.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final em = ref.watch(extensionManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.repo.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(widget.repo.url, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              TextButton(onPressed: _browse, child: Text(_expanded ? 'Hide' : 'Browse')),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => em.removeRepository(widget.repo.url),
              ),
            ]),
            if (_loading) const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            if (_error != null) Text(_error!, style: TextStyle(color: scheme.error)),
            if (_expanded && !_loading)
              for (final plugin in _plugins)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: _Icon(url: plugin.iconUrl, size: 32),
                  title: Text(plugin.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${plugin.packageName} · v${plugin.version}${plugin.language != null ? ' · ${plugin.language}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: _installButton(em, plugin),
                ),
          ],
        ),
      ),
    );
  }

  Widget _installButton(ExtensionManager em, SitePlugin plugin) {
    final installed = em.extensionById(plugin.packageName);
    if (installed != null) return const Chip(label: Text('Installed', style: TextStyle(fontSize: 11)));
    return FilledButton.tonal(
      onPressed: () async {
        try {
          await em.install(plugin, widget.repo.url);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${plugin.name} installed')));
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('AppException', ''))));
        }
      },
      child: const Text('Install'),
    );
  }
}

class _ExtensionCard extends ConsumerWidget {
  const _ExtensionCard({required this.extension});
  final InstalledExtension extension;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final em = ref.read(extensionManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _Icon(url: extension.iconUrl, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(extension.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('${extension.packageName} · v${extension.version}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
          Switch(value: extension.enabled, onChanged: (v) => em.setEnabled(extension.packageName, v)),
          IconButton(tooltip: 'Update', icon: const Icon(Icons.system_update_alt), onPressed: () => em.update(extension.packageName)),
          IconButton(tooltip: 'Remove', icon: const Icon(Icons.delete_outline), onPressed: () => em.uninstall(extension.packageName)),
        ]),
      ),
    );
  }
}

class _AddonCard extends ConsumerWidget {
  const _AddonCard({required this.addon});
  final ManagedAddon addon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final am = ref.read(addonManagerProvider);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: _Icon(url: addon.manifest.logoUrl, size: 40),
        title: Text(addon.manifest.name),
        subtitle: Text('${addon.manifest.id} · v${addon.manifest.version}\n${addon.manifest.catalogs.length} catalogs · ${addon.manifest.resources.join(', ')}',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Switch(value: addon.enabled, onChanged: (v) => am.setEnabled(addon.manifestUrl, v)),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => am.removeAddon(addon.manifestUrl)),
        ]),
      ),
    );
  }
}

class _BundledCard extends StatelessWidget {
  const _BundledCard({required this.plugin});
  final InstalledPlugin plugin;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public),
      title: Text('${plugin.name} (metadata)'),
      subtitle: Text('v${plugin.version} · ${plugin.platforms.map((p) => p.label).join(', ')}'),
    );
  }
}

class _Icon extends StatelessWidget {
  const _Icon({this.url, this.size = 40});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _fallback(context)),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.extension, size: size * 0.5),
      );
}
