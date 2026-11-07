import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../../data/repositories/attachment_repository.dart';
import '../common/date_time_field.dart';
import '../common/documents.dart';
import '../common/format.dart';
import 'commute_labels.dart';

/// One commuting cost. A recurring cost (monthly parking, a bridge fee every
/// commuting day) is entered once; a congestion tax invoice once per month.
class CommuteExpenseScreen extends ConsumerStatefulWidget {
  const CommuteExpenseScreen({super.key, this.expenseId});

  final int? expenseId;

  @override
  ConsumerState<CommuteExpenseScreen> createState() => _CommuteExpenseScreenState();
}

class _CommuteExpenseScreenState extends ConsumerState<CommuteExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  CommuteExpenseKind _kind = CommuteExpenseKind.congestionTax;
  ExpenseRecurrence _recurrence = ExpenseRecurrence.once;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _to;
  int? _routeId;
  bool _loaded = false;

  /// The invoice or receipt behind the cost, saved with it.
  late final _documents = DocumentDraft(
    ref.read(attachmentRepositoryProvider),
    AttachmentOwner.commuteExpense,
    ownerId: widget.expenseId,
  );

  bool get _isNew => widget.expenseId == null;

  @override
  void dispose() {
    _documents.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _loadFrom(CommuteExpenseRow e) {
    _kind = e.kind;
    _recurrence = e.recurrence;
    _amount.text = oreToInput(e.amountOre, AppLocalizations.of(context).localeName);
    _note.text = e.note;
    final f = CalendarDate.parse(e.fromDate);
    _from = DateTime(f.year, f.month, f.day);
    if (e.toDate != null) {
      final t = CalendarDate.parse(e.toDate!);
      _to = DateTime(t.year, t.month, t.day);
    }
    _routeId = e.routeId;
    _loaded = true;
  }

  /// The usual way each cost is paid, used when the type changes on a new
  /// cost: invoices once, parking monthly, fees per commuting day.
  static ExpenseRecurrence _defaultRecurrence(CommuteExpenseKind k) => switch (k) {
        CommuteExpenseKind.congestionTax => ExpenseRecurrence.once,
        CommuteExpenseKind.parking => ExpenseRecurrence.monthly,
        _ => ExpenseRecurrence.perCommuteDay,
      };

  String _iso(DateTime d) => CalendarDate(d.year, d.month, d.day).toIso();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final once = _recurrence == ExpenseRecurrence.once;
    final id = await ref.read(commuteRepositoryProvider).saveExpense(CommuteExpensesCompanion(
          id: _isNew ? const Value.absent() : Value(widget.expenseId!),
          kind: Value(_kind),
          recurrence: Value(_recurrence),
          amountOre: Value(parseKronorToOre(_amount.text)!),
          fromDate: Value(_iso(_from)),
          toDate: Value(once || _to == null ? null : _iso(_to!)),
          routeId: Value(_routeId),
          note: Value(_note.text.trim()),
        ));
    await _documents.save(id);
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteCostConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(attachmentRepositoryProvider).removeAll(AttachmentOwner.commuteExpense, widget.expenseId!);
    await ref.read(commuteRepositoryProvider).deleteExpense(widget.expenseId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(commuteDataProvider).value;
    if (!_loaded) {
      final match = data?.expenses.where((e) => e.id == widget.expenseId).firstOrNull;
      if (_isNew) {
        _loaded = true;
      } else if (match != null) {
        _loadFrom(match);
      } else {
        return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      }
    }
    final routes = data?.routes ?? const <CommuteRouteRow>[];
    final help = switch (_kind) {
      CommuteExpenseKind.congestionTax => l.helpCongestion,
      CommuteExpenseKind.parking => l.helpParking,
      _ => l.helpFees,
    };
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.newCost : l.editCost),
        actions: [
          if (!_isNew) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<CommuteExpenseKind>(
                initialValue: _kind,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.costKind),
                items: [
                  for (final k in CommuteExpenseKind.values)
                    DropdownMenuItem(value: k, child: Text(expenseKindLabel(l, k))),
                ],
                onChanged: (k) => setState(() {
                  _kind = k ?? _kind;
                  if (_isNew) _recurrence = _defaultRecurrence(_kind);
                }),
              ),
              const SizedBox(height: Space.sm),
              Text(
                help,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _kind.isParking ? TraktaColors.of(context).warning : muted,
                    ),
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.costAmount, suffixText: l.currencySuffix),
                validator: (v) => (parseKronorToOre(v ?? '') ?? 0) <= 0 ? l.costAmount : null,
              ),
              const SizedBox(height: Space.md),
              // Rebuilt with a key so a new default shows when the type changes.
              DropdownButtonFormField<ExpenseRecurrence>(
                key: ValueKey(_recurrence),
                initialValue: _recurrence,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.costRecurrence),
                items: [
                  for (final r in ExpenseRecurrence.values)
                    DropdownMenuItem(value: r, child: Text(recurrenceLabel(l, r))),
                ],
                onChanged: (r) => setState(() => _recurrence = r ?? _recurrence),
              ),
              const SizedBox(height: Space.md),
              DateField(
                label: _recurrence == ExpenseRecurrence.once ? l.date : l.fromDate,
                value: _from,
                onChanged: (v) => setState(() => _from = v),
              ),
              if (_recurrence != ExpenseRecurrence.once) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _to == null,
                  onChanged: (still) => setState(() => _to = still ? null : DateTime.now()),
                  title: Text(l.stillInUse),
                ),
                if (_to != null) DateField(label: l.untilOptional, value: _to!, onChanged: (v) => setState(() => _to = v)),
              ],
              if (routes.length > 1) ...[
                const SizedBox(height: Space.md),
                DropdownButtonFormField<int?>(
                  initialValue: _routeId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.costRoute),
                  items: [
                    DropdownMenuItem(value: null, child: Text(l.anyRoute)),
                    for (final r in routes) DropdownMenuItem(value: r.id, child: Text(r.label.isEmpty ? '—' : r.label)),
                  ],
                  onChanged: (v) => setState(() => _routeId = v),
                ),
              ],
              const SizedBox(height: Space.md),
              TextFormField(controller: _note, decoration: InputDecoration(labelText: l.note)),
              const SizedBox(height: Space.lg),
              DraftDocumentsSection(draft: _documents, help: l.documentsHelpCost),
            ],
          ),
        ),
      ),
    );
  }
}
