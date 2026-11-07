import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/time/zones.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Zones.ensureInitialized();
  final documents = await attachmentRoot();
  final backups = await backupFolders();
  runApp(ProviderScope(
    overrides: [
      attachmentRootProvider.overrideWithValue(documents),
      backupFoldersProvider.overrideWithValue(backups),
    ],
    child: const TraktaApp(),
  ));
}
