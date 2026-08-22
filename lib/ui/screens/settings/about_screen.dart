import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../version.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = AppInfo.version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (build ${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),
          Center(child: Icon(Icons.play_circle_fill_rounded, size: 72, color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 12),
          Center(child: Text(AppInfo.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
          Center(child: Text('Version $_version', style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(height: 24),
          const ListTile(leading: Icon(Icons.android), title: Text('Android'), subtitle: Text('SkyStream · Nuvio · CloudStream')),
          const ListTile(leading: Icon(Icons.desktop_windows_outlined), title: Text('Windows'), subtitle: Text('SkyStream · Nuvio')),
          const ListTile(leading: Icon(Icons.terminal_outlined), title: Text('Linux'), subtitle: Text('SkyStream · Nuvio')),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.extension),
            title: Text('Plugin architecture'),
            subtitle: Text('Providers are modular: install, enable, disable, update, reload, remove and configure without touching the core app.'),
          ),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Security'),
            subtitle: Text('HTTPS only. Plugins are validated (checksums when available) and never executed by the core app.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Source code'),
            onTap: () => launchUrl(Uri.parse(AppInfo.repository)),
          ),
          ListTile(
            leading: const Icon(Icons.balance),
            title: const Text('License'),
            subtitle: const Text('GNU General Public License v3.0'),
            onTap: () => launchUrl(Uri.parse('https://www.gnu.org/licenses/gpl-3.0.html')),
          ),
        ],
      ),
    );
  }
}
