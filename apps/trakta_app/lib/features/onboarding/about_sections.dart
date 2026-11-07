import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../l10n/app_localizations.dart';

/// The three things every user should know about Trakta. Shown once as the
/// onboarding pages and always available under Settings → About, with the
/// exact same text.
enum AboutTopic { what, disclaimer, offline }

/// One topic: an icon, a title, an introduction and a bulleted list.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key, required this.topic, this.large = false});

  final AboutTopic topic;

  /// Onboarding pages use a bigger icon and title than the About screen.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, title, intro, bullets) = switch (topic) {
      AboutTopic.what => (
          Icons.luggage_outlined,
          l.welcomeTitle,
          l.welcomeWhat,
          [l.welcomeWhatReturn, l.taxRulesNote],
        ),
      AboutTopic.disclaimer => (
          Icons.gavel_outlined,
          l.disclaimerTitle,
          l.disclaimerIntro,
          [l.disclaimerRules, l.disclaimerResponsible, l.disclaimerAsk],
        ),
      AboutTopic.offline => (
          Icons.lock_outline,
          l.offlineTitle,
          l.offlineNoInternet,
          [l.offlineOnPhone, l.offlineFree, l.offlineOwn, l.offlineRules],
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (large) ...[
          CircleAvatar(
            radius: 32,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            child: Icon(icon, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: Space.lg),
          Text(title, style: theme.textTheme.headlineSmall),
        ] else
          Row(children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          ]),
        const SizedBox(height: Space.md),
        Text(intro, style: large ? theme.textTheme.bodyLarge : null),
        for (final b in bullets)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(b, style: large ? theme.textTheme.bodyLarge : null)),
              ],
            ),
          ),
      ],
    );
  }
}
