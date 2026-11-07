import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/backup/backup_repository.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../common/format.dart';

/// Shortest password accepted for a new backup.
const minBackupPasswordLength = 8;

/// Asks for a password, writes the backup and lets the user save it as a file
/// anywhere on the phone (to move or upload later), or share it straight to
/// another app (Google Drive, email...).
Future<void> createBackup(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final origin = _originOf(context);
  final repo = ref.read(backupRepositoryProvider);
  final share = ref.read(shareFileProvider);
  final save = ref.read(saveFileProvider);

  final password = await showDialog<String>(context: context, builder: (_) => const BackupPasswordDialog(newPassword: true));
  if (password == null || !context.mounted) return;
  final File file;
  try {
    file = await _withProgress(context, l.backupCreating, () => repo.create(password));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l.backupFailed)));
    return;
  }
  if (!context.mounted) return;
  final target = await showDialog<_SaveTarget>(context: context, builder: (_) => const _SaveTargetDialog());
  var saved = false;
  try {
    saved = switch (target) {
      _SaveTarget.file => await save(file),
      _SaveTarget.share => await share(file, origin),
      null => false,
    };
  } catch (_) {
    saved = false;
  }
  if (saved) {
    await repo.markBackedUp(DateTime.now());
    messenger.showSnackBar(SnackBar(content: Text(l.backupCreated)));
  } else {
    messenger.showSnackBar(SnackBar(content: Text(l.backupNotSaved)));
  }
}

enum _SaveTarget { file, share }

/// Where the new backup goes: a file on the phone, or another app.
class _SaveTargetDialog extends StatelessWidget {
  const _SaveTargetDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SimpleDialog(
      title: Text(l.backupSaveTitle),
      children: [
        ListTile(
          leading: const Icon(Icons.save_alt),
          title: Text(l.backupSaveFile),
          subtitle: Text(l.backupSaveFileHint),
          onTap: () => Navigator.of(context).pop(_SaveTarget.file),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: Text(l.backupShare),
          subtitle: Text(l.backupShareHint),
          onTap: () => Navigator.of(context).pop(_SaveTarget.share),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
          ),
        ),
      ],
    );
  }
}

/// Lets the user pick a backup, asks for its password, shows what it holds
/// and, once confirmed, replaces everything on this phone with it. Returns
/// whether a backup was restored.
Future<bool> restoreBackup(BuildContext context, WidgetRef ref) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(backupRepositoryProvider);

  final picked = await ref.read(pickBackupFileProvider)();
  if (picked == null || !context.mounted) return false;

  BackupPreview? preview;
  String? passwordError;
  while (preview == null) {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => BackupPasswordDialog(newPassword: false, error: passwordError),
    );
    if (password == null || !context.mounted) return false;
    try {
      preview = await _withProgress(context, l.restoreOpening, () => repo.open(picked.read(), password));
    } on BackupException catch (e) {
      // A wrong password is the likely case: ask again, the rest is final.
      if (e.error == BackupError.wrongPasswordOrDamaged) {
        passwordError = l.backupErrorPassword;
        continue;
      }
      messenger.showSnackBar(SnackBar(content: Text(_errorText(l, e.error))));
      return false;
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.restoreFailed)));
      return false;
    }
    if (!context.mounted) return false;
  }

  final backup = preview;
  final confirmed = await showDialog<bool>(context: context, builder: (_) => _RestoreConfirmDialog(backup: backup, db: ref.read(databaseProvider)));
  if (confirmed != true || !context.mounted) {
    await repo.discard(backup);
    return false;
  }
  try {
    await _withProgress(context, l.restoreRestoring, () => repo.restore(backup));
  } catch (_) {
    await repo.discard(backup);
    messenger.showSnackBar(SnackBar(content: Text(l.restoreFailed)));
    return false;
  }
  messenger.showSnackBar(SnackBar(content: Text(l.restoreDone)));
  return true;
}

String _errorText(AppLocalizations l, BackupError e) => switch (e) {
      BackupError.wrongPasswordOrDamaged => l.backupErrorPassword,
      BackupError.notABackup => l.backupErrorNotBackup,
      BackupError.newerApp => l.backupErrorNewer,
      BackupError.damaged => l.backupErrorDamaged,
    };

/// Where the tapped widget is, so the share sheet points at it on iPad.
Rect? _originOf(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
}

/// Shows a spinner with [text] while [work] runs; the user cannot dismiss it.
Future<T> _withProgress<T>(BuildContext context, String text, Future<T> Function() work) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: Space.lg),
          Expanded(child: Text(text)),
        ]),
      ),
    ),
  ));
  try {
    return await work();
  } finally {
    navigator.pop();
  }
}

/// Asks for the backup password. For a new backup ([newPassword]) it is
/// typed twice, must be [minBackupPasswordLength] long, and comes with the
/// warning that it cannot be recovered. Returns null when cancelled.
class BackupPasswordDialog extends StatefulWidget {
  const BackupPasswordDialog({super.key, required this.newPassword, this.error});

  final bool newPassword;

  /// Shown under the field, e.g. after a wrong password.
  final String? error;

  @override
  State<BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<BackupPasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _hidden = true;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) Navigator.of(context).pop(_password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final toggle = IconButton(
      tooltip: _hidden ? l.passwordShow : l.passwordHide,
      icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _hidden = !_hidden),
    );
    return AlertDialog(
      title: Text(l.backupPasswordTitle),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          // Lets a password manager suggest and save the password.
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.newPassword ? l.backupPasswordIntro : l.restorePasswordIntro),
                const SizedBox(height: Space.md),
                TextFormField(
                  controller: _password,
                  obscureText: _hidden,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [widget.newPassword ? AutofillHints.newPassword : AutofillHints.password],
                  textInputAction: widget.newPassword ? TextInputAction.next : TextInputAction.done,
                  onFieldSubmitted: widget.newPassword ? null : (_) => _submit(),
                  decoration: InputDecoration(labelText: l.password, errorText: widget.error, errorMaxLines: 3, suffixIcon: toggle),
                  validator: (v) {
                    final text = v ?? '';
                    if (widget.newPassword && text.length < minBackupPasswordLength) {
                      return l.passwordTooShort(minBackupPasswordLength);
                    }
                    // Empty: nothing to say, but nothing to submit either.
                    return text.isEmpty ? '' : null;
                  },
                ),
                if (widget.newPassword) ...[
                  const SizedBox(height: Space.md),
                  TextFormField(
                    controller: _repeat,
                    obscureText: _hidden,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(labelText: l.passwordRepeat),
                    validator: (v) => v == _password.text ? null : l.passwordMismatch,
                  ),
                  const SizedBox(height: Space.md),
                  Text(l.backupPasswordWarning, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(widget.newPassword ? l.backupCreate : l.next)),
      ],
    );
  }
}

/// What the backup holds, and that restoring replaces everything here.
class _RestoreConfirmDialog extends StatelessWidget {
  const _RestoreConfirmDialog({required this.backup, required this.db});

  final BackupPreview backup;
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counts = [
      (l.navTrips, backup.count(db.trips)),
      (l.restoreDrives, backup.count(db.mileageEntries)),
      (l.vehicles, backup.count(db.vehicles)),
      (l.restoreRoutes, backup.count(db.commuteRoutes)),
      (l.documents, backup.count(db.attachments)),
    ];
    return AlertDialog(
      title: Text(l.restoreConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.restoreConfirmFrom(formatDate(context, CalendarDate.of(backup.createdUtc.toLocal())))),
            const SizedBox(height: Space.sm),
            for (final (label, count) in counts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(children: [Expanded(child: Text(label)), Text('$count', style: theme.textTheme.titleSmall)]),
              ),
            const SizedBox(height: Space.md),
            Text(l.restoreReplaceWarning, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.restoreAction)),
      ],
    );
  }
}
