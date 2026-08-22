import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_info.dart';
import '../../../core/providers.dart';
import '../../../providers/plugin_manager.dart';
import '../../../providers/provider.dart';

class PluginManagerScreen extends ConsumerWidget {
  const PluginManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = ref.watch(pluginManagerProvider);
    final plugins = pm.visibleOn(currentPlatform());

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
          Text('Installed Plugins', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final plugin in plugins) _PluginCard(plugin: plugin),
          if (plugins.isEmpty) const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('No plugins available on this platform.')),
          ),
          const SizedBox(height: 24),
          if (pm.logs.isNotEmpty) ...[
            Text('Logs', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final log in pm.logs.reversed.take(12))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '[${_time(log.timestamp)}] ${log.level.toUpperCase()} ${log.pluginId ?? ''} ${log.message}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _time(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PluginCard extends ConsumerWidget {
  const _PluginCard({required this.plugin});

  final InstalledPlugin plugin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pm = ref.read(pluginManagerProvider);
    final scheme = Theme.of(context).colorScheme;
    final isBundled = plugin.origin == PluginOrigin.bundled;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(child: Text(plugin.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        Text('v${plugin.version}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(width: 8),
                        if (isBundled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                            child: Text('bundled', style: TextStyle(fontSize: 10, color: scheme.onSecondaryContainer)),
                          ),
                      ]),
                      if (plugin.description != null)
                        Text(plugin.description!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch(
                  value: plugin.enabled,
                  onChanged: (v) => pm.setEnabled(plugin.id, v),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in plugin.platforms)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(p == ProviderPlatform.android ? Icons.android : (p == ProviderPlatform.windows ? Icons.desktop_windows_outlined : Icons.terminal_outlined), size: 14),
                    label: Text(p.label),
                  ),
                ...plugin.capabilities.labels.map((c) => Chip(visualDensity: VisualDensity.compact, label: Text(c))),
                if (plugin.updateAvailable != null)
                  Chip(visualDensity: VisualDensity.compact, label: const Text('update available'), backgroundColor: scheme.tertiaryContainer),
                if (plugin.status == ProviderStatus.error)
                  Chip(visualDensity: VisualDensity.compact, label: Text(plugin.lastError ?? 'error'), backgroundColor: scheme.errorContainer),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => pm.reload(plugin.id),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reload'),
                ),
                if (plugin.sourceUrl != null)
                  TextButton.icon(
                    onPressed: () => pm.update(plugin.id),
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: const Text('Update'),
                  ),
                TextButton.icon(
                  onPressed: () => _showConfigure(context, pm, plugin),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Configure'),
                ),
                TextButton.icon(
                  onPressed: () => _showDetails(context, plugin),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Details'),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: isBundled
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text('Remove ${plugin.name}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
                              ],
                            ),
                          );
                          if (ok == true) await pm.remove(plugin.id);
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, InstalledPlugin plugin) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plugin.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('ID', plugin.id),
              _kv('Version', plugin.version),
              _kv('Origin', plugin.origin.name),
              _kv('Source', plugin.sourceUrl ?? '—'),
              _kv('Checksum', plugin.checksum ?? '—'),
              _kv('Platforms', plugin.platforms.map((p) => p.label).join(', ')),
              _kv('Capabilities', plugin.capabilities.labels.join(', ')),
              _kv('Permissions', plugin.permissions.isEmpty ? '—' : plugin.permissions.join(', ')),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text('$k: $v', style: const TextStyle(fontSize: 13)),
      );

  void _showConfigure(BuildContext context, PluginManager pm, InstalledPlugin plugin) {
    final urlCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final qualityCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Configure ${plugin.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add a direct source URL (legitimate stream you own or have rights to play):', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Stream URL (https)')),
              TextField(controller: qualityCtrl, decoration: const InputDecoration(labelText: 'Quality (e.g. 1080p)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isEmpty || !url.startsWith('https://')) {
                Navigator.pop(ctx);
                return;
              }
              final existing = (plugin.config['directSources'] as List?)?.whereType<Map>().toList() ?? [];
              final updated = [
                ...existing,
                {
                  'name': nameCtrl.text.trim().isEmpty ? 'Direct source' : nameCtrl.text.trim(),
                  'url': url,
                  'quality': qualityCtrl.text.trim().isEmpty ? '1080p' : qualityCtrl.text.trim(),
                },
              ];
              Navigator.pop(ctx);
              await pm.configure(plugin.id, {'directSources': updated});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
