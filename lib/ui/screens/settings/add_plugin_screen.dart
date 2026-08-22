import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../../../providers/plugin_installer.dart';
import '../../../providers/url_validation.dart';

class AddPluginScreen extends ConsumerStatefulWidget {
  const AddPluginScreen({super.key});

  @override
  ConsumerState<AddPluginScreen> createState() => _AddPluginScreenState();
}

class _AddPluginScreenState extends ConsumerState<AddPluginScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  InstallOutcome? _success;

  String? get _validationError {
    final text = _controller.text.trim();
    if (text.isEmpty) return null;
    if (!text.startsWith('http')) {
      return ShortCodeResolverValid.validFormat(text) ? null : 'Short codes use letters and numbers only.';
    }
    return UrlValidation.error(text);
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
      final outcome = await ref.read(pluginManagerProvider).install(input);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _success = outcome;
      });
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Plugin installation failed.';
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Raw plugin URL', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Enter a legitimate HTTPS plugin URL, or a SkyStream short code.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'https://…  or  short code',
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
                    label: Text(_busy ? 'Installing…' : 'Validate & Install'),
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
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_success!.plugin.name} v${_success!.plugin.version} installed '
                            '${_success!.checksumVerified ? '(checksum verified)' : ''}',
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
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
                  Row(children: [
                    Icon(Icons.shield_outlined),
                    SizedBox(width: 8),
                    Text('How plugins are handled', style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  SizedBox(height: 8),
                  Text(
                    '• Only HTTPS URLs are accepted.\n'
                    '• Manifests are validated (id, name, version, platforms).\n'
                    '• Checksums/signatures are verified when provided.\n'
                    '• Plugin code is never executed by the core app.\n'
                    '• Plugins can be disabled, updated, reloaded or removed at any time.',
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

// Small helper to avoid importing the resolver here.
abstract final class ShortCodeResolverValid {
  static bool validFormat(String code) => RegExp(r'^[a-zA-Z0-9!_-]+$').hasMatch(code.trim());
}
