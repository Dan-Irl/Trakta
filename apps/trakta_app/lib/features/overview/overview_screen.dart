import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/providers.dart';
import '../../app/tokens.dart';
import '../../data/calculation/year_summary.dart';
import '../../l10n/app_localizations.dart';
import '../common/async_view.dart';
import '../common/format.dart';
import '../common/summary_widgets.dart';
import '../common/website_link.dart';

/// The first screen: what the user can expect to deduct for an income year
/// (the current one by default), and what to enter in which box of the tax
/// return. The sections themselves are one line each; the details live in
/// their tabs.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final data = ref.watch(overviewDataProvider);
    final commuteData = ref.watch(commuteDataProvider).value;
    final hasCommute = commuteData != null && !commuteData.isEmpty;
    final commute = hasCommute ? ref.watch(commuteResultProvider(_year)).value : null;
    final years = data.hasValue
        ? YearSummary.years(data.requireValue.trips.values, data.requireValue.lines, DateTime.now().year)
        : [_year];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navOverview),
        actions: [
          if (years.length > 1)
            PopupMenuButton<int>(
              tooltip: l.incomeYear,
              initialValue: _year,
              onSelected: (y) => setState(() => _year = y),
              itemBuilder: (context) => [for (final y in years) PopupMenuItem(value: y, child: Text('$y'))],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.md),
                child: Row(children: [Text('$_year'), const Icon(Icons.arrow_drop_down)]),
              ),
            ),
          IconButton(
            tooltip: l.navSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.go('/overview/settings'),
          ),
        ],
      ),
      body: AsyncView(
        value: data,
        builder: (context, d) {
          final s = YearSummary.of(_year, d.trips.values, d.lines, d.profile.userType, commute: commute);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: Space.sm),
            children: [
              _TotalCard(summary: s),
              _TaxReturnCard(summary: s, soleTrader: d.profile.userType == UserType.soleTrader),
              if (s.tripsNeedingInput > 0) _NeedsInputBanner(count: s.tripsNeedingInput),
              _TrackedCard(summary: s, hasCommute: hasCommute),
              const _WebsiteFooter(),
            ],
          );
        },
      ),
    );
  }
}

/// The one number the screen leads with.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.summary});
  final YearSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return SummaryCard(
      children: [
        Text(l.overviewTotal('${summary.year}'), style: text.titleSmall),
        const SizedBox(height: Space.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            context.money(summary.total),
            style: text.displayMedium?.copyWith(color: TraktaColors.of(context).positive),
          ),
        ),
        const SizedBox(height: Space.xs),
        Text(
          l.overviewTotalCaption,
          style: text.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// What to enter where: one row per box of the tax return, with what it
/// contains. Only boxes with something in them are shown.
class _TaxReturnCard extends StatelessWidget {
  const _TaxReturnCard({required this.summary, required this.soleTrader});
  final YearSummary summary;
  final bool soleTrader;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = summary;
    final c = s.commute;
    final travel = s.tripDeduction + s.drivingDeduction;
    final rows = [
      if (travel > Ore.zero)
        soleTrader
            ? _BoxRow(label: l.soleTraderBox, amount: travel, help: l.soleTraderBoxHelp)
            : _BoxRow(label: l.box22, amount: travel, help: l.box22Help),
      if (c != null && c.total > Ore.zero)
        _BoxRow(
          label: l.box21,
          amount: c.total,
          help: l.box21Help(context.money(c.threshold), context.money(c.deductible)),
        ),
      if (!soleTrader && s.box12Income > Ore.zero)
        _BoxRow(label: l.box12, amount: s.box12Income, help: l.box12Help, income: true),
    ];
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SummaryCard(
      title: l.taxReturnTitle('${s.year}'),
      icon: Icons.description_outlined,
      children: [
        if (rows.isEmpty)
          Text(l.taxReturnEmpty, style: TextStyle(color: muted))
        else ...[
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const Divider(height: Space.lg),
            row,
          ],
          const SizedBox(height: Space.md),
          Text(l.taxReturnCheck, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ],
    );
  }
}

class _BoxRow extends StatelessWidget {
  const _BoxRow({required this.label, required this.amount, required this.help, this.income = false});

  final String label;
  final Ore amount;
  final String help;

  /// Box 1.2 is income, not a deduction, so it is not in the positive colour.
  final bool income;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            const SizedBox(width: Space.sm),
            Text(
              context.money(amount),
              style: theme.textTheme.titleMedium?.copyWith(color: income ? null : TraktaColors.of(context).positive),
            ),
          ],
        ),
        const SizedBox(height: Space.xs),
        Text(help, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _NeedsInputBanner extends StatelessWidget {
  const _NeedsInputBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final warning = TraktaColors.of(context).warning;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs),
      color: warning.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: Icon(Icons.error_outline, color: warning),
        title: Text(AppLocalizations.of(context).overviewNeedsInput(count), style: TextStyle(color: warning)),
        trailing: Icon(Icons.chevron_right, color: warning),
        onTap: () => context.go('/trips'),
      ),
    );
  }
}

/// One line per section with what is tracked and what it gives; tapping
/// opens the section.
class _TrackedCard extends StatelessWidget {
  const _TrackedCard({required this.summary, required this.hasCommute});
  final YearSummary summary;
  final bool hasCommute;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = summary;
    final c = s.commute;
    final commuteMetres = c?.days.fold(0, (n, d) => n + d.metres) ?? 0;
    return SummaryCard(
      title: l.trackedTitle('${s.year}'),
      icon: Icons.insights_outlined,
      children: [
        _SectionTile(
          icon: Icons.luggage_outlined,
          title: l.navTrips,
          detail: s.trips == 0 ? null : '${l.tripsCount(s.trips)} · ${l.daysCount(s.days)}',
          amount: s.tripDeduction,
          route: s.trips == 0 ? '/trips/new' : '/trips',
        ),
        _SectionTile(
          icon: Icons.directions_car_outlined,
          title: l.navMileage,
          detail: s.drives == 0
              ? null
              : '${context.decimal(s.businessMetres / 1000, maxDigits: 0)} km · ${l.drivesCount(s.drives)}',
          amount: s.drivingDeduction,
          route: '/mileage',
        ),
        _SectionTile(
          icon: Icons.commute_outlined,
          title: l.navCommute,
          detail: !hasCommute || c == null
              ? null
              : '${l.daysCount(c.days.length)} · ${context.decimal(commuteMetres / 1000, maxDigits: 0)} km',
          amount: s.commuteDeduction,
          route: hasCommute ? '/commute' : '/commute/route/new',
        ),
      ],
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.amount,
    required this.route,
  });

  final IconData icon;
  final String title;

  /// Null when nothing is tracked yet.
  final String? detail;
  final Ore amount;
  final String route;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final detail = this.detail;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail ?? l.notStarted),
      trailing: detail == null
          ? const Icon(Icons.add)
          : Text(
              context.money(amount),
              style: theme.textTheme.titleMedium?.copyWith(color: TraktaColors.of(context).positive),
            ),
      onTap: () => context.go(route),
    );
  }
}

/// A quiet link to trakta.app at the end of the overview.
class _WebsiteFooter extends ConsumerWidget {
  const _WebsiteFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, Space.md, Space.md, Space.lg),
      child: Center(
        child: TextButton.icon(
          onPressed: () => openWebsite(context, ref),
          icon: Icon(Icons.public, size: 18, color: muted),
          label: Text('${l.websiteFooter} · ${l.websiteTitle}', style: TextStyle(color: muted)),
        ),
      ),
    );
  }
}
