import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/about_sections.dart';

/// Settings → About: the onboarding text, to read again at any time.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.aboutAndDisclaimer)),
      body: ListView(
        padding: const EdgeInsets.all(Space.md),
        children: [
          for (final (i, t) in AboutTopic.values.indexed) ...[
            if (i > 0) const Divider(height: Space.xl),
            AboutSection(topic: t),
          ],
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}
