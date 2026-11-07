import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'vehicles_screen.dart';

/// Vehicle type and ownership decide the mileage rate.
class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({super.key, this.vehicleId});

  final int? vehicleId;

  @override
  ConsumerState<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _registration = TextEditingController();
  Ownership _ownership = Ownership.own;
  Powertrain _powertrain = Powertrain.fossil;
  bool _employerPaysFuel = false;
  bool _onlyWorkplaceCharging = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.vehicleId == null) _loaded = true;
  }

  @override
  void dispose() {
    _label.dispose();
    _registration.dispose();
    super.dispose();
  }

  void _loadFrom(VehicleRow v) {
    _label.text = v.label;
    _registration.text = v.registration;
    _ownership = v.ownership;
    _powertrain = v.powertrain;
    _employerPaysFuel = v.employerPaysFuel;
    _onlyWorkplaceCharging = v.onlyWorkplaceCharging;
    _loaded = true;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final company = _ownership == Ownership.company;
    await ref.read(mileageRepositoryProvider).saveVehicle(VehiclesCompanion(
          id: widget.vehicleId == null ? const Value.absent() : Value(widget.vehicleId!),
          label: Value(_label.text.trim()),
          registration: Value(_registration.text.trim().toUpperCase()),
          ownership: Value(_ownership),
          powertrain: Value(_powertrain),
          employerPaysFuel: Value(company && _employerPaysFuel),
          onlyWorkplaceCharging:
              Value(company && _employerPaysFuel && _powertrain == Powertrain.pluginHybrid && _onlyWorkplaceCharging),
        ));
    if (mounted) context.pop();
  }

  Future<void> _archive() async {
    await ref.read(mileageRepositoryProvider).archiveVehicle(widget.vehicleId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_loaded) {
      final vehicles = ref.watch(vehiclesProvider);
      final match = vehicles.hasValue ? vehicles.requireValue.where((v) => v.id == widget.vehicleId).firstOrNull : null;
      if (match == null) {
        return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      }
      _loadFrom(match);
    }
    final company = _ownership == Ownership.company;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicleId == null ? l.addVehicle : l.editVehicle),
        actions: [
          if (widget.vehicleId != null)
            IconButton(tooltip: l.delete, icon: const Icon(Icons.archive_outlined), onPressed: _archive),
          TextButton(onPressed: _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(Space.md),
          children: [
            TextFormField(
              controller: _label,
              decoration: InputDecoration(labelText: l.vehicleLabel, hintText: l.vehicleLabelHint),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.labelRequired : null,
            ),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _registration,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: l.registration),
            ),
            const SizedBox(height: Space.md),
            Text(l.ownership, style: Theme.of(context).textTheme.titleSmall),
            RadioGroup<Ownership>(
              groupValue: _ownership,
              onChanged: (v) => setState(() => _ownership = v ?? Ownership.own),
              child: Column(children: [
                for (final o in Ownership.values)
                  RadioListTile<Ownership>(value: o, title: Text(ownershipLabel(l, o)), contentPadding: EdgeInsets.zero),
              ]),
            ),
            const SizedBox(height: Space.sm),
            DropdownButtonFormField<Powertrain>(
              isExpanded: true,
              initialValue: _powertrain,
              decoration: InputDecoration(labelText: l.powertrain),
              items: [
                for (final p in Powertrain.values) DropdownMenuItem(value: p, child: Text(powertrainLabel(l, p))),
              ],
              onChanged: (v) => setState(() => _powertrain = v ?? Powertrain.fossil),
            ),
            if (company) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _employerPaysFuel,
                onChanged: (v) => setState(() => _employerPaysFuel = v),
                title: Text(l.employerPaysFuel),
              ),
              if (_employerPaysFuel && _powertrain == Powertrain.pluginHybrid)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _onlyWorkplaceCharging,
                  onChanged: (v) => setState(() => _onlyWorkplaceCharging = v),
                  title: Text(l.onlyWorkplaceCharging),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
