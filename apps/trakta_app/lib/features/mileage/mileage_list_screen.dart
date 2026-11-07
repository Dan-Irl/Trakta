import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/mileage_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/format.dart';
import '../common/note_card.dart';

/// Business driving (körjournal): every drive in the job, with
/// its standard mileage amount, and the car allowance the employer pays
/// (set once here, copied onto each new drive). Commuting to the regular
/// workplace is a separate deduction with its own tab; the note at the top
/// says so, and that business driving decides commuting parking.
class MileageListScreen extends ConsumerWidget {
  const MileageListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final lines = ref.watch(mileageCalculationsProvider);
    final docs = ref.watch(attachmentCountsProvider(AttachmentOwner.mileageEntry)).value ?? const <int, int>{};
    final vehicles = ref.watch(vehiclesProvider);
    final hasVehicles = vehicles.hasValue && vehicles.requireValue.any((v) => !v.archived);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navMileage),
        actions: [
          IconButton(
            tooltip: l.vehicles,
            icon: const Icon(Icons.garage_outlined),
            onPressed: () => context.go('/mileage/vehicles'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(hasVehicles ? '/mileage/new' : '/mileage/vehicles/new'),
        icon: const Icon(Icons.add),
        label: Text(hasVehicles ? l.newEntry : l.addVehicle),
      ),
      body: AsyncView(
        value: lines,
        builder: (context, lines) {
          if (lines.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(Space.md),
              children: [
                const _BusinessDrivingNote(),
                const SizedBox(height: Space.md),
                const _AllowanceCard(),
                const SizedBox(height: Space.xl),
                Text(hasVehicles ? l.mileageEmpty : l.noVehicles, textAlign: TextAlign.center),
              ],
            );
          }
          // Year totals for business drives.
          final byYear = <int, ({Ore amount, int metres})>{};
          for (final line in lines) {
            final y = CalendarDate.parse(line.entry.date).year;
            final prev = byYear[y] ?? (amount: Ore.zero, metres: 0);
            byYear[y] = (amount: prev.amount + line.result.amount, metres: prev.metres + line.entry.distanceM);
          }
          final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView(
            padding: const EdgeInsets.only(bottom: Space.fabClearance),
            children: [
              const Padding(padding: EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, 0), child: _BusinessDrivingNote()),
              const Padding(padding: EdgeInsets.all(Space.md), child: _AllowanceCard()),
              for (final y in years)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.summarize_outlined),
                  title: Text(l.mileageYearTotal(
                    '$y',
                    context.money(byYear[y]!.amount),
                    context.decimal(byYear[y]!.metres / 1000, maxDigits: 0),
                  )),
                ),
              const Divider(height: 1),
              for (final line in lines)
                ListTile(
                  title: Text(
                    [line.entry.fromText, line.entry.toText].where((s) => s.isNotEmpty).join(' – ').ifEmpty(line.entry.purpose),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text([
                    formatDate(context, CalendarDate.parse(line.entry.date)),
                    line.vehicle.displayName,
                    '${context.decimal(line.entry.distanceM / 1000)} km',
                    if ((docs[line.entry.id] ?? 0) > 0) l.documentsCount(docs[line.entry.id]!),
                  ].join(' · ')),
                  trailing: Text(context.money(line.result.amount), style: Theme.of(context).textTheme.titleMedium),
                  onTap: () => context.go('/mileage/entry/${line.entry.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// What belongs here and what does not, and how it affects commuting.
class _BusinessDrivingNote extends StatelessWidget {
  const _BusinessDrivingNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NoteCard(title: l.navMileage, bullets: [l.businessDrivingIntro, l.businessDrivingAffectsParking]);
  }
}

/// The employer's car allowance (bilersättning) per mil, set once here and
/// copied onto each new drive.
class _AllowanceCard extends ConsumerWidget {
  const _AllowanceCard();

  Future<void> _edit(BuildContext context, WidgetRef ref, int? current) async {
    final result = await showDialog<({int? rate, bool applyYear})>(
      context: context,
      builder: (context) => _AllowanceDialog(current: current),
    );
    if (result == null) return;
    await ref.read(profileRepositoryProvider).update(ProfilesCompanion(carAllowanceOrePerMil: Value(result.rate)));
    if (result.applyYear) {
      await ref.read(mileageRepositoryProvider).setAllowanceForYear(DateTime.now().year, result.rate);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final rate = ref.watch(profileProvider).value?.carAllowanceOrePerMil;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: const Icon(Icons.payments_outlined),
        title: Text(l.carAllowanceTitle),
        subtitle: Text(rate == null ? l.carAllowanceNone : l.carAllowancePerMil(context.money(Ore(rate)))),
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => _edit(context, ref, rate),
      ),
    );
  }
}

class _AllowanceDialog extends StatefulWidget {
  const _AllowanceDialog({required this.current});
  final int? current;

  @override
  State<_AllowanceDialog> createState() => _AllowanceDialogState();
}

class _AllowanceDialogState extends State<_AllowanceDialog> {
  late bool _paid = widget.current != null;
  late final _amount = TextEditingController();
  bool _applyYear = false;
  bool _filled = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_filled) {
      if (widget.current != null) _amount.text = oreToInput(widget.current!, l.localeName);
      _filled = true;
    }
    final rate = parseKronorToOre(_amount.text);
    return AlertDialog(
      title: Text(l.carAllowanceTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _paid,
              onChanged: (v) => setState(() => _paid = v),
              title: Text(l.carAllowanceSwitch),
            ),
            if (_paid)
              TextField(
                controller: _amount,
                autofocus: widget.current == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.carAllowanceRate, suffixText: l.currencySuffix),
              ),
            const SizedBox(height: Space.sm),
            Text(l.carAllowanceHelp, style: Theme.of(context).textTheme.bodySmall),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _applyYear,
              onChanged: (v) => setState(() => _applyYear = v ?? false),
              title: Text(l.carAllowanceApplyYear('${DateTime.now().year}')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(
          onPressed: _paid && (rate == null || rate <= 0)
              ? null
              : () => Navigator.pop(context, (rate: _paid ? rate : null, applyYear: _applyYear)),
          child: Text(l.save),
        ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? (other.isEmpty ? '—' : other) : this;
}
