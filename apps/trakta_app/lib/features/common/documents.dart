import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/db/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../l10n/app_localizations.dart';

/// Lets the user pick documents and copies them into the app. Returns the
/// copied files, still to be linked to a record.
Future<List<StoredFile>> pickDocuments(WidgetRef ref) async {
  final picked = await ref.read(pickFilesProvider)();
  if (picked.isEmpty) return const [];
  final repo = ref.read(attachmentRepositoryProvider);
  return [for (final f in picked) await repo.import(f.name, f.read())];
}

/// Opens a stored document in the phone's own viewer, or says why it could
/// not.
Future<void> openDocument(BuildContext context, WidgetRef ref, StoredFile f) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final repo = ref.read(attachmentRepositoryProvider);
  final ok = await ref.read(openFileProvider)(repo.fileFor(f.sha256, f.fileName));
  if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.openFailed)));
}

StoredFile storedOf(AttachmentRow r) => StoredFile(fileName: r.fileName, sha256: r.sha256, sizeBytes: r.sizeBytes);

/// The documents of a record while its form is open. Changes are kept
/// until [save] (with the record's id, once it has one); picked files that
/// are never saved are deleted again by [dispose].
class DocumentDraft extends ChangeNotifier {
  DocumentDraft(this._repo, this.ownerType, {int? ownerId}) {
    if (ownerId != null) {
      _repo.watch(ownerType, ownerId).first.then((rows) {
        if (_disposed) return;
        _existing = rows;
        notifyListeners();
      });
    }
  }

  final AttachmentRepository _repo;
  final String ownerType;
  List<AttachmentRow> _existing = const [];
  final Set<int> _removed = {};
  final List<StoredFile> _added = [];
  bool _saved = false;
  bool _disposed = false;

  /// While picked files are being copied in.
  bool importing = false;

  /// What the form shows: stored files not removed, then the new ones.
  List<StoredFile> get files => [
        for (final r in _existing)
          if (!_removed.contains(r.id)) storedOf(r),
        ..._added,
      ];

  Future<void> pick(WidgetRef ref) async {
    importing = true;
    notifyListeners();
    try {
      final picked = await pickDocuments(ref);
      if (!_disposed) _added.addAll(picked);
    } finally {
      if (!_disposed) {
        importing = false;
        notifyListeners();
      }
    }
  }

  void remove(StoredFile f) {
    final i = _added.indexWhere((a) => a.sha256 == f.sha256 && a.fileName == f.fileName);
    if (i >= 0) {
      _added.removeAt(i);
      // Picked but never saved: delete the copy unless it was picked twice.
      if (!_added.any((a) => a.sha256 == f.sha256)) _repo.discard([f]);
    } else {
      final row = _existing.where((r) => r.sha256 == f.sha256 && r.fileName == f.fileName && !_removed.contains(r.id));
      if (row.isNotEmpty) _removed.add(row.first.id);
    }
    notifyListeners();
  }

  /// Links the new files to [ownerId] and deletes the removed ones.
  Future<void> save(int ownerId) async {
    await _repo.add(ownerType, ownerId, _added);
    for (final r in _existing.where((r) => _removed.contains(r.id))) {
      await _repo.remove(r);
    }
    _saved = true;
  }

  @override
  void dispose() {
    _disposed = true;
    if (!_saved && _added.isNotEmpty) _repo.discard([..._added]);
    super.dispose();
  }
}

/// [DocumentsSection] for a form, driven by a [DocumentDraft].
class DraftDocumentsSection extends ConsumerWidget {
  const DraftDocumentsSection({super.key, required this.draft, this.help});
  final DocumentDraft draft;

  /// What belongs here; the trip text when null.
  final String? help;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListenableBuilder(
        listenable: draft,
        builder: (context, _) => DocumentsSection(
          help: help,
          files: draft.files,
          busy: draft.importing,
          onAdd: () => draft.pick(ref),
          onOpen: (f) => openDocument(context, ref, f),
          onRemove: draft.remove,
        ),
      );
}

/// One document: an icon by type, its name and size; tap opens it.
class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.file, required this.onOpen, required this.onRemove});

  final StoredFile file;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ext = p.extension(file.fileName).toLowerCase();
    final icon = switch (ext) {
      '.pdf' => Icons.picture_as_pdf_outlined,
      '.jpg' || '.jpeg' || '.png' || '.heic' || '.webp' => Icons.image_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBytes(file.sizeBytes)),
      trailing: IconButton(tooltip: l.removeDocument, icon: const Icon(Icons.close), onPressed: onRemove),
      onTap: onOpen,
    );
  }
}

/// The documents part of a form or card: help text, the files, and an add
/// button. The caller decides what adding and removing mean (straight into
/// the database, or kept until the form is saved).
class DocumentsSection extends StatelessWidget {
  const DocumentsSection({
    super.key,
    required this.files,
    required this.onAdd,
    required this.onOpen,
    required this.onRemove,
    this.busy = false,
    this.help,
  });

  final List<StoredFile> files;
  final VoidCallback onAdd;
  final ValueChanged<StoredFile> onOpen;
  final ValueChanged<StoredFile> onRemove;

  /// While picked files are being copied in.
  final bool busy;

  /// What belongs here; the trip text when null.
  final String? help;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.documents, style: theme.textTheme.titleSmall),
        const SizedBox(height: Space.xs),
        Text(help ?? l.documentsHelp, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        for (final f in files) DocumentTile(file: f, onOpen: () => onOpen(f), onRemove: () => onRemove(f)),
        const SizedBox(height: Space.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onAdd,
            icon: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.attach_file),
            label: Text(l.addDocument),
          ),
        ),
      ],
    );
  }
}
