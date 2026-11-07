import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repositories/mileage_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../data/repositories/attachment_repository.dart';
import '../common/date_time_field.dart';
import '../common/documents.dart';
import '../common/format.dart';
import '../common/reason_text.dart';

/// One business drive in the körjournal. The distance is entered
/// either as a number of km or as odometer readings, never both. The car
/// allowance is a rate per mil, taken from the tab's setting for new drives.
class MileageEditScreen extends ConsumerStatefulWidget {
  const MileageEditScreen({super.key, this.entryId});

  final int? entryId;

  @override
  ConsumerState<MileageEditScreen> createState() => _MileageEditScreenState();
}

class _MileageEditScreenState extends ConsumerState<MileageEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odoStart = TextEditingController();
  final _odoEnd = TextEditingController();
  final _distance = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _purpose = TextEditingController();
  final _visited = TextEditingController();
  final _congestion = TextEditingController();
  final _toll = TextEditingController();
  final _allowance = TextEditingController();
  DateTime _date = DateTime.now();
  int? _vehicleId;
  bool _loaded = false;

  /// Odometer readings instead of a distance in km.
  bool _useOdometer = false;

  /// New drives start from the user's usual mode and allowance once.
  bool _defaultsApplied = false;

  /// Receipts and other proof for the drive, saved with it.
  late final _documents = DocumentDraft(
    ref.read(attachmentRepositoryProvider),
    AttachmentOwner.mileageEntry,
    ownerId: widget.entryId,
  );

  @override
  void initState() {
    super.initState();
    if (widget.entryId == null) _loaded = true;
    for (final c in [_odoStart, _odoEnd, _distance, _allowance]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_odoStart, _odoEnd, _distance, _from, _to, _purpose, _visited, _congestion, _toll, _allowance]) {
      c.dispose();
    }
    _documents.dispose();
    super.dispose();
  }

  void _loadFrom(MileageEntryRow e) {
    final d = CalendarDate.parse(e.date);
    _date = DateTime(d.year, d.month, d.day);
    _vehicleId = e.vehicleId;
    _odoStart.text = e.odoStart?.toString() ?? '';
    _odoEnd.text = e.odoEnd?.toString() ?? '';
    final lang = AppLocalizations.of(context).localeName;
    _distance.text = formatDecimal(lang, e.distanceM / 1000).replaceAll(RegExp(r'[\s\u00a0,](?=\d{3})'), '');
    _from.text = e.fromText;
    _to.text = e.toText;
    _purpose.text = e.purpose;
    _visited.text = e.visited;
    _useOdometer = e.odoStart != null && e.odoEnd != null;
    _congestion.text = oreToInput(e.congestionTaxOre, lang);
    _toll.text = oreToInput(e.tollOre, lang);
    _allowance.text = e.allowanceOrePerMil == null ? '' : oreToInput(e.allowanceOrePerMil!, lang);
    _loaded = true;
    _defaultsApplied = true;
  }

  /// Distance in metres, from whichever way the user entered it.
  int? get _distanceMetres {
    if (_useOdometer) {
      final start = int.tryParse(_odoStart.text.trim());
      final end = int.tryParse(_odoEnd.text.trim());
      return start != null && end != null && end > start ? (end - start) * 1000 : null;
    }
    final km = double.tryParse(_distance.text.trim().replaceAll(',', '.'));
    if (km == null || km <= 0) return null;
    return (km * 1000).round();
  }

  CalendarDate get _calendarDate => CalendarDate(_date.year, _date.month, _date.day);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final metres = _distanceMetres;
    if (metres == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.distanceRequired)));
      return;
    }
    if (_vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.noVehicles)));
      return;
    }
    final id = await ref.read(mileageRepositoryProvider).saveEntry(MileageEntriesCompanion(
          id: widget.entryId == null ? const Value.absent() : Value(widget.entryId!),
          date: Value(_calendarDate.toIso()),
          vehicleId: Value(_vehicleId!),
          odoStart: Value(_useOdometer ? int.tryParse(_odoStart.text.trim()) : null),
          odoEnd: Value(_useOdometer ? int.tryParse(_odoEnd.text.trim()) : null),
          distanceM: Value(metres),
          fromText: Value(_from.text.trim()),
          toText: Value(_to.text.trim()),
          purpose: Value(_purpose.text.trim()),
          visited: Value(_visited.text.trim()),
          congestionTaxOre: Value(parseKronorToOre(_congestion.text) ?? 0),
          tollOre: Value(parseKronorToOre(_toll.text) ?? 0),
          allowanceOrePerMil: Value(_allowanceRate),
        ));
    await _documents.save(id);
    if (mounted) context.pop();
  }

  /// The allowance rate in öre per mil; null when empty or zero.
  int? get _allowanceRate {
    final ore = parseKronorToOre(_allowance.text);
    return ore == null || ore <= 0 ? null : ore;
  }

  Future<void> _delete() async {
    await ref.read(attachmentRepositoryProvider).removeAll(AttachmentOwner.mileageEntry, widget.entryId!);
    await ref.read(mileageRepositoryProvider).deleteEntry(widget.entryId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final library = ref.watch(rulesLibraryProvider);

    if (!_loaded) {
      final entries = ref.watch(mileageEntriesProvider);
      final match = entries.hasValue ? entries.requireValue.where((e) => e.id == widget.entryId).firstOrNull : null;
      if (match == null) {
        return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      }
      _loadFrom(match);
    }
    if (!_defaultsApplied) {
      // A new drive: the allowance from the tab's setting, and the same way
      // of entering the distance as the latest drive.
      final profile = ref.watch(profileProvider).value;
      final entries = ref.watch(mileageEntriesProvider).value;
      if (profile != null && entries != null) {
        final rate = profile.carAllowanceOrePerMil;
        if (rate != null) _allowance.text = oreToInput(rate, l.localeName);
        final latest = entries.firstOrNull;
        _useOdometer = latest != null && latest.odoStart != null && latest.odoEnd != null;
        _defaultsApplied = true;
      }
    }

    final vehicles = vehiclesAsync.hasValue
        ? vehiclesAsync.requireValue.where((v) => !v.archived || v.id == _vehicleId).toList()
        : <VehicleRow>[];
    _vehicleId ??= vehicles.firstOrNull?.id;
    final vehicle = vehicles.where((v) => v.id == _vehicleId).firstOrNull;

    // Live preview of the standard amount.
    MileageResult? preview;
    final metres = _distanceMetres;
    if (vehicle != null && metres != null && library.hasValue) {
      preview = MileageCalculator.calculate(
        MileageInput(date: _calendarDate, distanceMetres: metres, isBusiness: true),
        vehicle.toInput(),
        library.requireValue,
      );
    }

    final kronor = <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9,. ]'))];
    final digits = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entryId == null ? l.newEntry : l.editEntry),
        actions: [
          if (widget.entryId != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            DateField(label: l.date, value: _date, onChanged: (v) => setState(() => _date = v)),
            const SizedBox(height: Space.md),
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: _vehicleId,
              decoration: InputDecoration(labelText: l.vehicle),
              items: [for (final v in vehicles) DropdownMenuItem(value: v.id, child: Text(v.displayName))],
              onChanged: (v) => setState(() => _vehicleId = v),
            ),
            const SizedBox(height: Space.md),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.distanceMode), icon: const Icon(Icons.straighten)),
                ButtonSegment(value: true, label: Text(l.odometerMode), icon: const Icon(Icons.speed)),
              ],
              selected: {_useOdometer},
              onSelectionChanged: (v) => setState(() => _useOdometer = v.single),
            ),
            const SizedBox(height: Space.md),
            if (_useOdometer)
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _odoStart,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(labelText: l.odoStart),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: TextFormField(
                    controller: _odoEnd,
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    decoration: InputDecoration(
                      labelText: l.odoEnd,
                      helperText: metres == null ? null : '= ${context.decimal(metres / 1000)} km',
                    ),
                    validator: (v) {
                      final s = int.tryParse(_odoStart.text.trim());
                      final e = int.tryParse((v ?? '').trim());
                      return (s != null && e != null && e <= s) ? l.odoInvalid : null;
                    },
                  ),
                ),
              ])
            else
              TextFormField(
                controller: _distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: kronor,
                decoration: InputDecoration(labelText: l.distanceKm, suffixText: 'km'),
              ),
            const SizedBox(height: Space.md),
            TextFormField(controller: _from, decoration: InputDecoration(labelText: l.fromPlace)),
            const SizedBox(height: Space.md),
            TextFormField(controller: _to, decoration: InputDecoration(labelText: l.toPlace)),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _purpose,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.mileagePurpose),
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _visited,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.visited, hintText: l.visitedHint),
            ),
            const SizedBox(height: Space.md),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _congestion,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kronor,
                    decoration: InputDecoration(labelText: l.congestionTax),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: TextFormField(
                    controller: _toll,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: kronor,
                    decoration: InputDecoration(labelText: l.toll),
                  ),
                ),
              ]),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _allowance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: kronor,
                decoration: InputDecoration(
                  labelText: l.driveAllowance,
                  suffixText: l.currencySuffix,
                  helperMaxLines: 2,
                  helperText: _allowanceRate != null && metres != null
                      ? l.driveAllowanceTotal(context.money(Ore(_allowanceRate!).times(metres, 10000)))
                      : l.driveAllowanceEmpty,
                ),
              ),
            if (preview != null) ...[
              const SizedBox(height: Space.md),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(Space.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.money(preview.amount), style: Theme.of(context).textTheme.displaySmall),
                      const SizedBox(height: Space.xs),
                      for (final r in preview.reasons)
                        Text('• ${reasonText(l, r)}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: Space.lg),
            DraftDocumentsSection(draft: _documents, help: l.documentsHelpDrive),
          ],
        ),
      ),
    );
  }
}
