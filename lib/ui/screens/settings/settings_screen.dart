import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/storage/settings_store.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStoreProvider);
    final cache = ref.watch(depsProvider).cacheStore;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _section(context, 'TMDB'),
          _navTile(context, icon: Icons.key, title: 'TMDB API key', subtitle: 'Configure metadata, posters and search', onTap: () => context.push('/settings/tmdb')),

          _section(context, 'Playback'),
          _dropdownTile<SourceSelectionMode>(
            context,
            title: 'Source selection',
            value: settings.sourceSelectionMode,
            items: SourceSelectionMode.values,
            label: (v) => v.name,
            onChanged: (v) => settings.sourceSelectionMode = v,
          ),
          SwitchListTile(
            title: const Text('Autoplay next episode'),
            subtitle: const Text('Start the next episode automatically'),
            value: settings.autoplayNext,
            onChanged: (v) => settings.autoplayNext = v,
          ),
          SwitchListTile(
            title: const Text('Resume playback'),
            subtitle: const Text('Continue where you left off'),
            value: settings.resumePlayback,
            onChanged: (v) => settings.resumePlayback = v,
          ),
          SwitchListTile(
            title: const Text('Subtitles'),
            subtitle: const Text('Prefer subtitles when available'),
            value: settings.subtitlesEnabled,
            onChanged: (v) => settings.subtitlesEnabled = v,
          ),
          _dropdownTile<double>(
            context,
            title: 'Playback speed',
            value: settings.playbackSpeed,
            items: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
            label: (v) => v == 1.0 ? '1×' : '$v×',
            onChanged: (v) => settings.playbackSpeed = v,
          ),
          _dropdownTile<String>(
            context,
            title: 'Default quality',
            value: settings.defaultQuality,
            items: const ['Auto', 'Highest', '1080p', '720p', '480p'],
            label: (v) => v,
            onChanged: (v) => settings.defaultQuality = v,
          ),
          _dropdownTile<String>(
            context,
            title: 'Audio language',
            value: settings.audioLanguage,
            items: const ['Original', 'en', 'ur', 'ar', 'es', 'fr'],
            label: (v) => v,
            onChanged: (v) => settings.audioLanguage = v,
          ),

          _section(context, 'Plugins'),
          _navTile(context, icon: Icons.extension, title: 'Installed plugins', subtitle: 'Manage SkyStream, Nuvio and CloudStream', onTap: () => context.push('/settings/plugins')),
          _navTile(context, icon: Icons.add_circle_outline, title: 'Add plugin', subtitle: 'Raw plugin URL or SkyStream short code', onTap: () => context.push('/settings/plugins/add')),

          _section(context, 'Appearance'),
          _dropdownTile<ThemePreference>(
            context,
            title: 'Theme',
            value: settings.themePreference,
            items: ThemePreference.values,
            label: (v) => v.name,
            onChanged: (v) => settings.themePreference = v,
          ),
          _dropdownTile<UiDensity>(
            context,
            title: 'UI density',
            value: settings.density,
            items: UiDensity.values,
            label: (v) => v.name,
            onChanged: (v) => settings.density = v,
          ),
          _dropdownTile<String>(
            context,
            title: 'Metadata language',
            value: settings.language,
            items: const ['en', 'ur', 'ar', 'es', 'fr', 'de'],
            label: (v) => v,
            onChanged: (v) => settings.language = v,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 10,
              children: const [0xFF7C4DFF, 0xFFE91E63, 0xFF03A9F4, 0xFF00C853, 0xFFFF9800, 0xFF607D8B]
                  .map((c) => _AccentDot(
                        color: Color(c),
                        selected: settings.accentColor == c,
                        onTap: () => settings.accentColor = c,
                      ))
                  .toList(),
            ),
          ),

          _section(context, 'Storage'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Cache'),
            subtitle: Text('${cache.size} cached entries'),
          ),
          _actionTile(context, title: 'Clear image cache', onTap: () async {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            _snack(context, 'Image cache cleared.');
          }),
          _actionTile(context, title: 'Clear metadata cache', onTap: () async {
            await cache.clear();
            if (!context.mounted) return;
            _snack(context, 'Metadata cache cleared.');
          }),
          _actionTile(context, title: 'Clear all cache', onTap: () async {
            PaintingBinding.instance.imageCache.clear();
            PaintingBinding.instance.imageCache.clearLiveImages();
            await cache.clear();
            if (!context.mounted) return;
            _snack(context, 'All caches cleared.');
          }),

          _section(context, 'Network'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('HTTPS only'),
            subtitle: Text('All traffic uses encrypted connections with timeouts and retries.'),
          ),

          _section(context, 'About'),
          _navTile(context, icon: Icons.info_outline, title: 'About StreamHub', subtitle: 'Version and license', onTap: () => context.push('/settings/about')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      );

  Widget _navTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _actionTile(BuildContext context, {required String title, required VoidCallback onTap}) {
    return ListTile(title: Text(title), leading: const Icon(Icons.delete_outline), onTap: onTap);
  }

  Widget _dropdownTile<T>(BuildContext context, {required String title, required T value, required List<T> items, required String Function(T) label, required ValueChanged<T> onChanged}) {
    return ListTile(
      title: Text(title),
      trailing: DropdownButton<T>(
        value: items.contains(value) ? value : items.first,
        items: items.map((v) => DropdownMenuItem<T>(value: v, child: Text(label(v)))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _AccentDot extends StatelessWidget {
  const _AccentDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }
}
