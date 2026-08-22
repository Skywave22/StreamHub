import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class TmdbSettingsScreen extends ConsumerStatefulWidget {
  const TmdbSettingsScreen({super.key});

  @override
  ConsumerState<TmdbSettingsScreen> createState() => _TmdbSettingsScreenState();
}

class _TmdbSettingsScreenState extends ConsumerState<TmdbSettingsScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  bool _hasKey = false;
  String? _status;
  bool _statusOk = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final hasKey = await ref.read(tmdbServiceProvider).hasApiKey;
    if (!mounted) return;
    setState(() => _hasKey = hasKey);
  }

  Future<void> _test() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final ok = await ref.read(tmdbServiceProvider).testKey(key);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusOk = ok;
        _status = ok ? 'Key is valid ✓' : 'Authentication failed. Check your API key.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusOk = false;
        _status = 'Could not reach TMDB. Check your connection.';
      });
    }
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    if (key.isEmpty) return;
    await ref.read(tmdbServiceProvider).saveApiKey(key);
    await _refresh();
    setState(() {
      _statusOk = true;
      _status = 'API key saved.';
    });
  }

  Future<void> _remove() async {
    await ref.read(tmdbServiceProvider).clearApiKey();
    _controller.clear();
    await _refresh();
    setState(() {
      _statusOk = true;
      _status = 'API key removed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('TMDB')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.key, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('TMDB API key', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'StreamHub uses TMDB for metadata: posters, backdrops, cast, ratings, seasons and episodes. '
                    'Get a free API key at themoviedb.org and paste it below. The key is stored securely on this device.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'API key',
                      hintText: 'Paste your TMDB API key',
                      suffixIcon: _hasKey ? const Icon(Icons.check_circle, color: Colors.green) : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _test,
                        icon: const Icon(Icons.wifi_tethering),
                        label: const Text('Test'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                    ),
                  ]),
                  if (_hasKey) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _remove,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove key'),
                      ),
                    ),
                  ],
                  if (_status != null) ...[
                    const SizedBox(height: 8),
                    Text(_status!, style: TextStyle(color: _statusOk ? Colors.green : scheme.error)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
