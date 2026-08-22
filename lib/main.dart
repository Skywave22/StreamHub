import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'app_dependencies.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final supportDir = await getApplicationSupportDirectory();
  final deps = await AppDependencies.create(hiveDir: supportDir.path);

  runApp(
    ProviderScope(
      overrides: [depsProvider.overrideWithValue(deps)],
      child: const StreamHubApp(),
    ),
  );
}
