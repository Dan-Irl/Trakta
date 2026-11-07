import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/calculation/trip_calculations.dart';
import '../../data/db/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/country_picker.dart';
import '../common/documents.dart';
import '../common/format.dart';
import '../common/reason_text.dart';
import 'day_edit_sheet.dart';
import 'day_summary.dart';

/// Day review and result for one trip, including what the employer paid.
/// Every edit re-runs the pure engine.
class TripDetailScreen extends ConsumerWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final int tripId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteTripConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    // Documents have no foreign key (they can belong to any record type).
    await ref.read(attachmentRepositoryProvider).removeAll(AttachmentOwner.trip, tripId);
    await ref.read(tripRepositoryProvider).delete(tripId);
    if (context.mounted) context.go('/trips');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final calcs = ref.watch(tripCalculationsProvider);
    final library = ref.watch(rulesLibraryProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.summary),
        actions: [
          IconButton(
            tooltip: l.edit,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.go('/trips/$tripId/edit'),
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: AsyncView(
        value: calcs,
        builder: (context, byId) {
          final calc = byId[tripId];
          if (calc == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xl),
            children: [
              _Header(calc: calc),
              if (calc.result.missingYears.isNotEmpty)
                TripBanner(text: l.updateAppForYear(calc.result.missingYears.join(', ')), error: true),
              if (!calc.result.eligible)
                TripBanner(
                  text: [
                    l.notEligibleTitle,
                    ...calc.result.eligibilityReasons.map((r) => '• ${reasonText(l, r)}'),
                  ].join('\n'),
                ),
              TripSummaryCard(calc: calc),
              _EmployerPaidCard(calc: calc),
              _NotesAndDocumentsCard(tripId: tripId, note: calc.bundle.trip.note),
              Padding(
                padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.xs),
                child: Text(l.days, style: Theme.of(context).textTheme.titleSmall),
              ),
              for (final day in calc.result.days) _DayCard(calc: calc, day: day),
              if (library.hasValue) _RulesFooter(calc: calc, library: library.requireValue),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.calc});
  final TripCalculation calc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = calc.bundle.trip;
    final theme = Theme.of(context);
    final library = ref.watch(rulesLibraryProvider).value;
    final pack = library == null ? null : packForYear(library, calc.bundle.departureWall.year);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.md, Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.purpose, style: theme.textTheme.headlineSmall),
          const SizedBox(height: Space.xs),
          Text(
            [
              if (!isSwedenKey(t.country)) countryLabel(l, pack, t.country),
              '${formatWall(context, calc.bundle.departureWall)} – ${formatWall(context, calc.bundle.returnWall)}',
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class TripBanner extends StatelessWidget {
  const TripBanner({super.key, required this.text, this.error = false});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      color: error ? scheme.error.withValues(alpha: 0.12) : scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Text(text, style: error ? TextStyle(color: scheme.error) : null),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.positive = false});
  final String label;
  final String value;
  final bool bold;

  /// Deduction amounts use the positive colour (DESIGN.md).
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = bold ? text.titleMedium : text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: positive ? style?.copyWith(color: TraktaColors.of(context).positive) : style),
        ],
      ),
    );
  }
}

class TripSummaryCard extends StatelessWidget {
  const TripSummaryCard({super.key, required this.calc});
  final TripCalculation calc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = calc.result;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          children: [
            _Row('${l.perDiem} (${l.daysCount(r.days.length)})', context.money(r.perDiemTotal)),
            _Row('${l.nightAllowance} (${l.nightsCount(r.nights.length)})', context.money(r.nightTotal)),
            const Divider(),
            _Row(l.total, context.money(r.total), bold: true),
          ],
        ),
      ),
    );
  }
}

class _EmployerPaidCard extends ConsumerWidget {
  const _EmployerPaidCard({required this.calc});
  final TripCalculation calc;

  Future<void> _editPayment(BuildContext context, WidgetRef ref, EmployerPaymentKind kind, String label) async {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController(text: oreToInput(calc.bundle.paidOre(kind), l.localeName));
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: l.currencySuffix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, parseKronorToOre(controller.text) ?? 0),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(tripRepositoryProvider).setPayment(calc.bundle.trip.id, kind, result);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileProvider);
    final soleTrader = profile.hasValue && profile.requireValue.userType == UserType.soleTrader;
    final per = calc.perDiem;
    final night = calc.nights;

    if (soleTrader) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Padding(
          padding: const EdgeInsets.all(Space.md),
          child: Column(children: [
            _Row(l.businessDeduction, context.money(per.businessDeduction + night.businessDeduction), bold: true, positive: true),
            const SizedBox(height: Space.sm),
            Text(reasonText(l, per.reasons.first), style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0),
            child: Text(l.employerPaid, style: Theme.of(context).textTheme.titleSmall),
          ),
          ListTile(
            title: Text(l.employerPaidPerDiem),
            trailing: Text(context.money(per.paid)),
            onTap: () => _editPayment(context, ref, EmployerPaymentKind.perDiem, l.employerPaidPerDiem),
          ),
          ListTile(
            title: Text(l.employerPaidNight),
            trailing: Text(context.money(night.paid)),
            onTap: () => _editPayment(context, ref, EmployerPaymentKind.night, l.employerPaidNight),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(Space.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Row(l.taxFree, context.money(per.taxFree + night.taxFree)),
                _Row(l.taxableExcess, context.money(per.taxableExcess + night.taxableExcess)),
                _Row(l.box12, context.money(per.box12Income + night.box12Income)),
                _Row(l.box22, context.money(per.box22Deduction + night.box22Deduction), bold: true, positive: true),
                const SizedBox(height: Space.sm),
                for (final r in {...per.reasons, ...night.reasons})
                  Text('• ${reasonText(l, r)}', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The trip's notes (edited in the trip form) and its documents, which can
/// be opened, added and removed right here.
class _NotesAndDocumentsCard extends ConsumerStatefulWidget {
  const _NotesAndDocumentsCard({required this.tripId, required this.note});
  final int tripId;
  final String note;

  @override
  ConsumerState<_NotesAndDocumentsCard> createState() => _NotesAndDocumentsCardState();
}

class _NotesAndDocumentsCardState extends ConsumerState<_NotesAndDocumentsCard> {
  bool _importing = false;

  Future<void> _add() async {
    setState(() => _importing = true);
    try {
      final files = await pickDocuments(ref);
      if (files.isEmpty) return;
      await ref.read(attachmentRepositoryProvider).add(AttachmentOwner.trip, widget.tripId, files);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rows = ref.watch(attachmentsProvider((AttachmentOwner.trip, widget.tripId))).value ?? const <AttachmentRow>[];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
      child: Padding(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.note.isNotEmpty) ...[
              Text(l.notes, style: theme.textTheme.titleSmall),
              const SizedBox(height: Space.xs),
              SelectableText(widget.note),
              const SizedBox(height: Space.lg),
            ],
            DocumentsSection(
              files: [for (final r in rows) storedOf(r)],
              busy: _importing,
              onAdd: _add,
              onOpen: (f) => openDocument(context, ref, f),
              onRemove: (f) async {
                final row = rows.firstWhere((r) => r.sha256 == f.sha256 && r.fileName == f.fileName);
                await ref.read(attachmentRepositoryProvider).remove(row);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.calc, required this.day});
  final TripCalculation calc;
  final DayResult day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final row = calc.bundle.days.where((d) => d.date == day.date.toIso()).firstOrNull;
    final night = calc.result.nights.where((n) => n.evening == day.date).firstOrNull;

    final subtitle = daySubtitle(l, calc, day);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(formatDayDate(context, day.date)),
        subtitle: Text(subtitle),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(context.money(day.amount), style: theme.textTheme.titleMedium),
            if (night != null)
              Text('+ ${context.money(night.amount)}', style: theme.textTheme.bodySmall),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.md),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.why, style: theme.textTheme.titleSmall),
          const SizedBox(height: Space.xs),
          for (final r in day.reasons) Text('• ${reasonText(l, r)}', style: theme.textTheme.bodySmall),
          if (night != null) ...[
            const SizedBox(height: Space.sm),
            Text(l.nightAllowance, style: theme.textTheme.titleSmall),
            for (final r in night.reasons) Text('• ${reasonText(l, r)}', style: theme.textTheme.bodySmall),
          ],
          if (row != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.edit),
                onPressed: () async {
                  final changed = await showDayEditSheet(
                    context,
                    row: row,
                    hasNight: night != null,
                    tripCountry: calc.bundle.trip.country,
                    tripMeals: calc.bundle.tripMealsOn(row.date),
                    tripLodging: calc.bundle.trip.lodging,
                  );
                  if (changed != null) await ref.read(tripRepositoryProvider).updateDay(changed);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesFooter extends StatelessWidget {
  const _RulesFooter({required this.calc, required this.library});
  final TripCalculation calc;
  final RulesLibrary library;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final years = calc.result.days.map((d) => d.date.year).toSet();
    final packs = [for (final y in years) ?library.forYear(y)];
    if (packs.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.md),
      child: Text(
        l.rulesFooter(
          packs.map((p) => p.packVersion).join(', '),
          packs.map((p) => p.foreignRatesTakenOn.toIso()).join(', '),
        ),
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}
