import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../data/repositories/mileage_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';

String ownershipLabel(AppLocalizations l, Ownership o) => switch (o) {
      Ownership.own => l.ownershipOwn,
      Ownership.company => l.ownershipCompany,
    };

String powertrainLabel(AppLocalizations l, Powertrain p) => switch (p) {
      Powertrain.fossil => l.powertrainFossil,
      Powertrain.pluginHybrid => l.powertrainPluginHybrid,
      Powertrain.electric => l.powertrainElectric,
    };

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.vehicles)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/mileage/vehicles/new'),
        icon: const Icon(Icons.add),
        label: Text(l.addVehicle),
      ),
      body: AsyncView(
        value: ref.watch(vehiclesProvider),
        builder: (context, vehicles) {
          final active = vehicles.where((v) => !v.archived).toList();
          if (active.isEmpty) {
            return Center(child: Text(l.noVehicles));
          }
          return ListView(
            children: [
              for (final v in active)
                ListTile(
                  leading: Icon(v.powertrain == Powertrain.electric ? Icons.electric_car : Icons.directions_car),
                  title: Text(v.displayName),
                  subtitle: Text([
                    ownershipLabel(l, v.ownership),
                    powertrainLabel(l, v.powertrain),
                  ].join(' · ')),
                  onTap: () => context.go('/mileage/vehicles/${v.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
