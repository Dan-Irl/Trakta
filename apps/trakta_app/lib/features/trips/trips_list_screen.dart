import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/calculation/trip_calculations.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/country_picker.dart';
import '../common/format.dart';

class TripsListScreen extends ConsumerWidget {
  const TripsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final calcs = ref.watch(tripCalculationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.navTrips)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/trips/new'),
        icon: const Icon(Icons.add),
        label: Text(l.newTrip),
      ),
      body: AsyncView(
        value: calcs,
        builder: (context, byId) {
          if (byId.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Space.xl),
                child: Text(l.tripsEmpty, textAlign: TextAlign.center),
              ),
            );
          }
          final list = byId.values.toList()
            ..sort((a, b) => b.bundle.trip.startUtc.compareTo(a.bundle.trip.startUtc));
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: Space.fabClearance),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _TripTile(calc: list[i]),
          );
        },
      ),
    );
  }
}

class _TripTile extends ConsumerWidget {
  const _TripTile({required this.calc});

  final TripCalculation calc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final trip = calc.bundle.trip;
    final r = calc.result;
    final theme = Theme.of(context);

    final String status;
    Color? statusColor;
    if (r.missingYears.isNotEmpty) {
      status = l.updateAppForYear('${r.missingYears.first}');
      statusColor = theme.colorScheme.error;
    } else if (!r.eligible) {
      status = l.tripNotEligible;
      statusColor = theme.colorScheme.onSurfaceVariant;
    } else if (!r.isComplete) {
      status = l.tripNeedsInput;
      statusColor = TraktaColors.of(context).warning;
    } else {
      status = '${l.daysCount(r.days.length)} · ${l.nightsCount(r.nights.length)}';
    }

    final library = ref.watch(rulesLibraryProvider).value;
    final pack = library == null ? null : packForYear(library, calc.bundle.departureWall.year);
    final place = [
      if (!isSwedenKey(trip.country)) countryLabel(l, pack, trip.country),
      '',
    ].join(' · ');
    return ListTile(
      title: Text(trip.purpose.isEmpty ? '—' : trip.purpose, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '$place${formatWall(context, calc.bundle.departureWall)} – ${formatWall(context, calc.bundle.returnWall)}\n$status',
        style: statusColor == null ? null : TextStyle(color: statusColor),
      ),
      isThreeLine: true,
      trailing: Text(context.money(r.total), style: theme.textTheme.titleMedium),
      onTap: () => context.go('/trips/${trip.id}'),
    );
  }
}
