import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_flow.dart';
import 'about_sections.dart';

/// Shown the first time the app opens: what Trakta does, that it is not tax
/// advice, and that it is offline and free with the data on the phone. The
/// user confirms the disclaimer before starting; the same text stays
/// available under Settings → About. Someone moving from another phone can
/// restore their backup instead; the restored profile skips these pages.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _pages = PageController();
  int _page = 0;
  bool _accepted = false;

  static const _topics = AboutTopic.values;
  bool get _last => _page == _topics.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  static const _turn = Duration(milliseconds: 250);

  Future<void> _start() async {
    await ref.read(profileRepositoryProvider).update(const ProfilesCompanion(onboardingDone: Value(true)));
    if (mounted) context.go('/overview');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  for (final t in _topics)
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(Space.lg, Space.xl, Space.lg, Space.md),
                      child: AboutSection(topic: t, large: true),
                    ),
                ],
              ),
            ),
            if (_page == 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: TextButton.icon(
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text(l.welcomeRestore),
                  onPressed: () => restoreBackup(context, ref),
                ),
              ),
            if (_last)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  title: Text(l.welcomeAccept),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: _page == 0
                        ? null
                        : TextButton(
                            onPressed: () => _pages.previousPage(duration: _turn, curve: Curves.easeOut),
                            child: Text(l.back),
                          ),
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _topics.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: Space.xs),
                            width: i == _page ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? scheme.primary : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: _last
                        ? FilledButton(onPressed: _accepted ? _start : null, child: Text(l.welcomeStart))
                        : FilledButton(
                            onPressed: () => _pages.nextPage(duration: _turn, curve: Curves.easeOut),
                            child: Text(l.next),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
