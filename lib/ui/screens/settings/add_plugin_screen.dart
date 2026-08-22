import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../providers/extensions/repository_service.dart';

enum _Mode { repository, addon }

class AddPluginScreen extends ConsumerStatefulWidget {
  const AddPluginScreen({super.key});

  @override
  ConsumerState<AddPluginScreen> createState() => _AddPluginScreenState();
}

class _AddPluginScreenState extends ConsumerState<AddPluginScreen> {
  final TextEditingController _controller = TextEditingController();
  _Mode _mode = _Mode.repository;
  bool _busy = false;
  String? _error;
  String? _success;

  String? get _validationError {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    if (_mode == _Mode.repository) {
      if (RepositoryService.looksLikeShortCode(text)) return null;
      if (text.startsWith('https://')) return null;
      return 'Enter a SkyStream short code or an HTTPS repository URL.';
    }
    if (!text.startsWith('https://')) return 'Enter an HTTPS addon manifest URL.';
    return null;
  }

  Future<void> _install() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      if (_mode == _Mode.repository) {
        final repo = await ref.read(extensionManagerProvider).addRepository(input);
        setState(() => _success = 'Repository "${repo.name}" added. Browse it to install extensions.');
      } else {
        final addon = await ref.read(addonManagerProvider).addAddon(input);
        setState(() => _success = 'Addon "${addon.manifest.name}" added.');
      }
      if (mounted) setState(() => _busy = false);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not add the plugin.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final validationError = _validationError;
    return Scaffold(
      appBar: AppBar(title: const Text('Add plugin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.repository, icon: Icon(Icons.hub_outlined), label: Text('Repository / short code')),
              ButtonSegment(value: _Mode.addon, icon: Icon(Icons.extension_outlined), label: Text('Stremio / Nuvio addon')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _mode == _Mode.repository
                        ? 'SkyStream / CloudStream repository'
                        : 'Stremio-compatible addon',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _mode == _Mode.repository
                        ? 'Enter a SkyStream short code (e.g. "hexated") or a repository URL.'
                        : 'Enter an addon manifest URL (https://…/manifest.json).',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _mode == _Mode.repository ? 'short code or https://…' : 'https://…/manifest.json',
                      prefixIcon: const Icon(Icons.link),
                      errorText: validationError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy || validationError != null ? null : _install,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: Text(_busy ? 'Adding…' : 'Add'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Icon(Icons.error_outline, color: scheme.onErrorContainer),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                      ]),
                    ),
                  ],
                  if (_success != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_success!, style: const TextStyle(color: Colors.green))),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.shield_outlined), SizedBox(width: 8), Text('How plugins run', style: TextStyle(fontWeight: FontWeight.w700))]),
                  SizedBox(height: 8),
                  Text(
                    '• Repositories and addon manifests are fetched and validated.\n'
                    '• Extensions are JavaScript and run in an isolated QuickJS engine.\n'
                    '• Plugin checksums are verified when repositories declare them.\n'
                    '• Everything can be disabled, updated or removed at any time.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
