import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/build_info.dart';
import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_flow.dart';
import '../common/async_view.dart';
import '../common/format.dart';
import '../common/website_link.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _userTypeLabel(AppLocalizations l, UserType t) => switch (t) {
        UserType.employee => l.userTypeEmployee,
        UserType.soleTrader => l.userTypeSoleTrader,
        UserType.companyOwner => l.userTypeCompanyOwner,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final repo = ref.watch(profileRepositoryProvider);
    final library = ref.watch(rulesLibraryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: AsyncView<ProfileRow>(
        value: ref.watch(profileProvider),
        builder: (context, profile) {
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
                child: DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: profile.localeCode,
                  decoration: InputDecoration(labelText: l.language),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.languageSystem)),
                    // Language names are always shown in their own language.
                    const DropdownMenuItem(value: 'sv', child: Text('Svenska')),
                    const DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => unawaited(repo.update(ProfilesCompanion(localeCode: Value(v)))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, 0),
                child: DropdownButtonFormField<UserType>(
                  initialValue: profile.userType,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.userType),
                  items: [
                    for (final t in UserType.values) DropdownMenuItem(
                        value: t,
                        child: Text(_userTypeLabel(l, t), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) unawaited(repo.update(ProfilesCompanion(userType: Value(v))));
                  },
                ),
              ),
              const Divider(),
              ListTile(title: Text(l.backupSection, style: theme.textTheme.titleSmall)),
              Builder(
                // Its own context, so the share sheet points at this row on iPad.
                builder: (context) => ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(l.backupCreate),
                  subtitle: Text(switch (profile.lastBackupUtc) {
                    null => l.backupNever,
                    final at => l.backupLast(formatDate(context, CalendarDate.of(at.toLocal()))),
                  }),
                  onTap: () => createBackup(context, ref),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(l.backupRestore),
                subtitle: Text(l.backupRestoreSubtitle),
                onTap: () => restoreBackup(context, ref),
              ),
              const Divider(),
              ListTile(title: Text(l.rulesPacks, style: theme.textTheme.titleSmall)),
              if (library.hasValue)
                for (final p in library.requireValue.packs)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.rule_folder_outlined),
                    title: Text(l.rulesPackLine('${p.incomeYear}', p.packVersion, p.foreignRatesTakenOn.toIso())),
                  ),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(l.glossary),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/overview/settings/glossary'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l.aboutAndDisclaimer),
                subtitle: Text(l.disclaimerTitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/overview/settings/about'),
              ),
              ListTile(
                leading: const Icon(Icons.public),
                title: Text(l.websiteTitle),
                subtitle: Text(l.websiteSubtitle),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openWebsite(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: Text(l.sourceCodeTitle),
                subtitle: Text(l.sourceCodeSubtitle),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => openWebsite(context, ref, WebsitePage.source),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l.licences),
                subtitle: Text(l.licencesSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Trakta',
                  applicationVersion: l.versionLine(appVersionName, appBuildNumber),
                  applicationLegalese: l.licenceLegalese,
                ),
              ),
              _VersionTile(channel: ref.watch(distributionChannelProvider)),
            ],
          );
        },
      ),
    );
  }
}

/// The version and where updates come from. A GitHub build cannot update
/// itself (no internet access), so its row opens the download page.
class _VersionTile extends ConsumerWidget {
  const _VersionTile({required this.channel});

  final DistributionChannel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final github = channel == DistributionChannel.github;
    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: Text(l.versionLine(appVersionName, appBuildNumber)),
      subtitle: Text(switch (channel) {
        DistributionChannel.github => l.channelGithub,
        DistributionChannel.googlePlay => l.channelGooglePlay,
        DistributionChannel.apple => l.channelApple,
        DistributionChannel.source => l.channelSource,
      }),
      trailing: github ? const Icon(Icons.open_in_new) : null,
      onTap: github ? () => openWebsite(context, ref, WebsitePage.download) : null,
    );
  }
}
