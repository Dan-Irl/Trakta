import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/db/database.dart';
import '../../data/repositories/commute_repository.dart';
import '../../data/repositories/mileage_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/date_time_field.dart';
import '../common/format.dart';
import '../common/note_card.dart';

/// A commuting route: home to the regular workplace, the car, and the days
/// of the week it is driven. The schedule is what makes daily input
/// unnecessary.
class CommuteRouteScreen extends ConsumerStatefulWidget {
  const CommuteRouteScreen({super.key, this.routeId});

  final int? routeId;

  @override
  ConsumerState<CommuteRouteScreen> createState() => _CommuteRouteScreenState();
}

class _CommuteRouteScreenState extends ConsumerState<CommuteRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _km = TextEditingController();
  int? _vehicleId;
  Set<int> _weekdays = {1, 2, 3, 4, 5};
  DateTime _start = DateTime(DateTime.now().year);
  DateTime? _end;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _km.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    _km.dispose();
    super.dispose();
  }

  void _loadFrom(CommuteRouteRow r) {
    final lang = AppLocalizations.of(context).localeName;
    _label.text = r.label;
    _km.text = formatDecimal(lang, r.oneWayM / 1000).replaceAll(RegExp(r'[\s ,](?=\d{3})'), '');
    _vehicleId = r.vehicleId;
    _weekdays = parseWorkDays(r.workDays);
    final s = CalendarDate.parse(r.startDate);
    _start = DateTime(s.year, s.month, s.day);
    if (r.endDate != null) {
      final e = CalendarDate.parse(r.endDate!);
      _end = DateTime(e.year, e.month, e.day);
    }
    _loaded = true;
  }

  int? get _metres {
    final km = double.tryParse(_km.text.trim().replaceAll(',', '.'));
    return km == null || km <= 0 ? null : (km * 1000).round();
  }

  String _iso(DateTime d) => CalendarDate(d.year, d.month, d.day).toIso();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _vehicleId == null || _weekdays.isEmpty) return;
    await ref.read(commuteRepositoryProvider).saveRoute(CommuteRoutesCompanion(
          id: widget.routeId == null ? const Value.absent() : Value(widget.routeId!),
          label: Value(_label.text.trim()),
          vehicleId: Value(_vehicleId!),
          oneWayM: Value(_metres!),
          workDays: Value(formatWorkDays(_weekdays)),
          startDate: Value(_iso(_start)),
          endDate: Value(_end == null ? null : _iso(_end!)),
        ));
    if (mounted) context.pop();
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteRouteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(commuteRepositoryProvider).deleteRoute(widget.routeId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_loaded) {
      final data = ref.watch(commuteDataProvider);
      final match = data.value?.routes.where((r) => r.id == widget.routeId).firstOrNull;
      if (widget.routeId == null) {
        _loaded = true;
      } else if (match != null) {
        _loadFrom(match);
      } else {
        return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      }
    }
    // Archived cars are hidden, except the one the route already uses: the
    // dropdown needs its value among the items, and the user can switch.
    final vehicles = (ref.watch(vehiclesProvider).value ?? const <VehicleRow>[])
        .where((v) => !v.archived || v.id == _vehicleId)
        .toList();
    _vehicleId ??= vehicles.firstOrNull?.id;
    final rules = ref.watch(rulesLibraryProvider).value?.forYear(_start.year)?.commute;
    final minKm = rules?.carMinKm ?? 5;
    final metres = _metres;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routeId == null ? l.newRoute : l.editRoute),
        actions: [
          if (widget.routeId != null) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
          TextButton(onPressed: vehicles.isEmpty ? null : _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoteCard(
                title: l.commuteRequirementsTitle,
                bullets: [l.commuteReqDistance('$minKm'), l.commuteReqTime('${rules?.minTimeSavedHours ?? 2}')],
                footer: '${l.commuteReqConfirm}\n${l.commuteIntroWhat}',
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _label,
                decoration: InputDecoration(labelText: l.routeLabel, hintText: l.routeLabelHint),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: Space.md),
              TextFormField(
                controller: _km,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l.oneWayKm,
                  helperText: metres != null && metres < minKm * 1000 ? l.routeTooShort('$minKm') : l.oneWayKmHelp,
                  helperMaxLines: 3,
                  helperStyle: metres != null && metres < minKm * 1000
                      ? TextStyle(color: TraktaColors.of(context).warning)
                      : null,
                ),
                validator: (_) => _metres == null ? l.distanceRequired : null,
              ),
              const SizedBox(height: Space.md),
              if (vehicles.isEmpty) ...[
                Text(l.chooseVehicleFirst),
                const SizedBox(height: Space.sm),
                OutlinedButton.icon(
                  onPressed: () => context.go('/mileage/vehicles/new'),
                  icon: const Icon(Icons.add),
                  label: Text(l.addVehicle),
                ),
              ] else
                DropdownButtonFormField<int>(
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l.vehicle),
                  items: [for (final v in vehicles) DropdownMenuItem(value: v.id, child: Text(v.displayName))],
                  onChanged: (v) => setState(() => _vehicleId = v),
                ),
              const SizedBox(height: Space.md),
              Text(l.commuteWeekdays, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: Space.sm),
              Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(weekdayShort(l, d)),
                      selected: _weekdays.contains(d),
                      onSelected: (on) => setState(() => _weekdays = {..._weekdays}..toggle(d, on)),
                    ),
                ],
              ),
              const SizedBox(height: Space.md),
              DateField(label: l.fromDate, value: _start, onChanged: (v) => setState(() => _start = v)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _end == null,
                onChanged: (still) => setState(() => _end = still ? null : DateTime.now()),
                title: Text(l.stillInUse),
              ),
              if (_end != null)
                DateField(label: l.untilOptional, value: _end!, onChanged: (v) => setState(() => _end = v)),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Set<int> {
  void toggle(int value, bool on) => on ? add(value) : remove(value);
}
