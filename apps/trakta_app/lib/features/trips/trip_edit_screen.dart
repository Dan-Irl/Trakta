import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:trakta_core/trakta_core.dart';

import '../../app/tokens.dart';
import '../../app/providers.dart';
import '../../data/calculation/trip_calculations.dart';
import '../../data/db/database.dart';
import '../../data/repositories/attachment_repository.dart';
import '../../data/repositories/trip_repository.dart';
import '../../l10n/app_localizations.dart';
import '../common/country_picker.dart';
import '../common/date_time_field.dart';
import '../common/documents.dart';
import '../common/note_card.dart';
import 'day_edit_sheet.dart' show TripChoiceField, lodgingLabel, mealLabel, tripLodgingOptions;
import 'trip_days_step.dart';

/// Create or edit a business trip. The app is for
/// trips that give a deduction, so the form lists the requirements instead of
/// asking about them: adding a trip confirms that it was ordered by the
/// employer and goes more than 50 km away. The engine checks the overnight
/// stay from the dates.
///
/// A new trip starts with the employer setup (per diem, lodging, meals) of
/// the latest trip, since most people travel the same way each time.
///
/// A new trip is made in two steps: the trip's details, then a review of the
/// days they give, where single days can be changed. Nothing is saved until
/// the last step, and then the trip and its days are saved together.
class TripEditScreen extends ConsumerStatefulWidget {
  const TripEditScreen({super.key, this.tripId});

  final int? tripId;

  @override
  ConsumerState<TripEditScreen> createState() => _TripEditScreenState();
}

class _TripEditScreenState extends ConsumerState<TripEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _note = TextEditingController();

  /// The trip's documents, saved together with the trip.
  late final _documents = DocumentDraft(
    ref.read(attachmentRepositoryProvider),
    AttachmentOwner.trip,
    ownerId: widget.tripId,
  );
  late DateTime _departure;
  late DateTime _return;
  String _country = swedenName;
  bool _employerPays = true;
  bool _nightWorker = false;
  MealStatus _breakfast = MealStatus.none;
  MealStatus _lunch = MealStatus.none;
  MealStatus _dinner = MealStatus.none;
  LodgingKind _lodging = LodgingKind.standard;
  bool _loaded = false;

  /// Whether a new trip's employer setup was copied from the latest trip.
  bool _copiedSetup = false;
  bool _saving = false;

  /// 0: trip details, 1: review days (new trips only).
  int _step = 0;

  /// Days by ISO date, kept when going back to the details and forward again.
  final Map<String, TripDayRow> _days = {};

  bool get _isNew => widget.tripId == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _departure = DateTime.utc(now.year, now.month, now.day, 8);
    _return = _departure.add(const Duration(days: 1, hours: 9));
  }

  @override
  void dispose() {
    _purpose.dispose();
    _note.dispose();
    _documents.dispose();
    super.dispose();
  }

  void _loadFrom(TripBundle b) {
    _purpose.text = b.trip.purpose;
    _departure = b.departureWall;
    _return = b.returnWall;
    _country = b.trip.country;
    _employerPays = b.trip.employerPaysPerDiem;
    _nightWorker = b.trip.nightWorker;
    _breakfast = b.trip.breakfast;
    _lunch = b.trip.lunch;
    _dinner = b.trip.dinner;
    _lodging = b.trip.lodging;
    _note.text = b.trip.note;
    _loaded = true;
  }

  void _copySetupFrom(TripRow? latest) {
    if (latest != null) {
      _employerPays = latest.employerPaysPerDiem;
      _lodging = latest.lodging;
      _breakfast = latest.breakfast;
      _lunch = latest.lunch;
      _dinner = latest.dinner;
      _copiedSetup = true;
    }
    _loaded = true;
  }

  TripDraft get _draft => TripDraft(
    purpose: _purpose.text,
    departure: _departure,
    returnTime: _return,
    country: _country,
    confirmedBusinessTrip: true,
    confirmed50km: true,
    employerPaysPerDiem: _employerPays,
    nightWorker: _nightWorker,
    breakfast: _breakfast,
    lunch: _lunch,
    dinner: _dinner,
    lodging: _lodging,
    note: _note.text.trim(),
  );

  bool _validDetails() {
    if (!_formKey.currentState!.validate()) return false;
    if (!_return.isAfter(_departure)) {
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.returnBeforeDeparture)));
      return false;
    }
    return true;
  }

  /// The trip's days: the ones already reviewed, plus fresh ones for new dates.
  List<TripDayRow> _daysFor(TripDraft draft) => [for (final date in draft.dates) _days[date] ?? newTripDay(0, date)];

  void _next() {
    if (!_validDetails()) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  Future<void> _save() async {
    if (_step == 0 && !_validDetails()) return;
    setState(() => _saving = true);
    final draft = _draft;
    final id = await ref.read(tripRepositoryProvider).save(
          draft,
          id: widget.tripId,
          days: _isNew ? _daysFor(draft) : const [],
        );
    await _documents.save(id);
    if (!mounted) return;
    if (_isNew) {
      context.go('/trips/$id');
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (!_loaded) {
      final bundles = ref.watch(tripBundlesProvider);
      final match = bundles.hasValue
          ? bundles.requireValue.where((b) => b.trip.id == widget.tripId).firstOrNull
          : null;
      if (_isNew && bundles.hasValue) {
        final trips = bundles.requireValue.map((b) => b.trip);
        _copySetupFrom(trips.isEmpty ? null : trips.reduce((a, b) => a.createdUtc.isAfter(b.createdUtc) ? a : b));
      } else if (match != null) {
        _loadFrom(match);
      } else {
        return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
      }
    }

    final library = ref.watch(rulesLibraryProvider).value;
    final pack = library == null ? null : packForYear(library, _departure.year);

    final Widget action;
    if (!_isNew) {
      action = TextButton(onPressed: _saving ? null : _save, child: Text(l.save));
    } else if (_step == 0) {
      action = TextButton(onPressed: _next, child: Text(l.next));
    } else {
      action = TextButton(onPressed: _saving ? null : _save, child: Text(l.createTrip));
    }

    return PopScope(
      // Back from the review goes to the trip's details, not out of the flow.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isNew
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_step == 0 ? l.newTrip : l.reviewDays),
                    Text(l.stepOf(_step + 1, 2), style: Theme.of(context).textTheme.bodySmall),
                  ],
                )
              : Text(l.editTrip),
          actions: [action],
        ),
        // The details stay mounted so their fields keep their state.
        body: IndexedStack(
          index: _step,
          children: [_details(context, pack), if (_step == 1) _review(library) else const SizedBox.shrink()],
        ),
      ),
    );
  }

  Widget _review(RulesLibrary? library) {
    final profile = ref.watch(profileProvider).value;
    if (library == null || profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final draft = _draft;
    final bundle = TripBundle(
      // No stored trip has id 0 (ids start at 1).
      trip: draft.toRow(),
      days: _daysFor(draft),
      segments: const [],
      payments: const [],
    );
    return TripDaysStep(
      calc: TripCalculations.compute(bundle, library, profile),
      onDayChanged: (day) => setState(() => _days[day.date] = day),
    );
  }

  Widget _details(BuildContext context, RulesPack? pack) {
    final l = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      // Not a lazy ListView: fields scrolled out of view must stay mounted
      // so the form still validates them.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Requirements(),
            const SizedBox(height: Space.md),
            TextFormField(
              controller: _purpose,
              decoration: InputDecoration(labelText: l.purpose, hintText: l.purposeHint),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().isEmpty) ? l.purposeRequired : null,
            ),
            const SizedBox(height: Space.md),
            DateTimeField(
              label: l.departure,
              value: _departure,
              onChanged: (v) => setState(() {
                final length = _return.difference(_departure);
                _departure = v;
                if (!_return.isAfter(_departure)) _return = _departure.add(length.isNegative ? Duration.zero : length);
              }),
            ),
            const SizedBox(height: Space.md),
            DateTimeField(label: l.returnHome, value: _return, onChanged: (v) => setState(() => _return = v)),
            const SizedBox(height: Space.md),
            if (pack != null) ...[
              CountryField(
                label: l.country,
                helperText: l.countryTripHelp,
                pack: pack,
                value: _country,
                onChanged: (v) => setState(() => _country = v ?? swedenName),
              ),
              const SizedBox(height: Space.md),
            ],
            const SizedBox(height: Space.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _nightWorker,
              onChanged: (v) => setState(() => _nightWorker = v),
              title: Text(l.nightWorker),
            ),
            const SizedBox(height: Space.md),
            Text(l.employerSetup, style: Theme.of(context).textTheme.titleSmall),
            if (_copiedSetup) ...[
              const SizedBox(height: Space.xs),
              Text(l.employerSetupCopied, style: Theme.of(context).textTheme.bodySmall),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _employerPays,
              onChanged: (v) => setState(() => _employerPays = v),
              title: Row(
                children: [
                  Flexible(child: Text(l.employerPaysPerDiem)),
                  _InfoButton(title: l.employerPaysPerDiem, text: l.employerPaysPerDiemHelp),
                ],
              ),
            ),
            // Lodging is its own question, not part of the per diem switch.
            const Divider(height: Space.lg),
            TripChoiceField(
              label: l.lodgingTrip,
              helperText: l.lodgingTripHelp,
              value: _lodging,
              options: tripLodgingOptions,
              optionLabel: lodgingLabel,
              onChanged: (v) => setState(() => _lodging = v!),
            ),
            const SizedBox(height: Space.lg),
            Text(l.mealsTrip, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Space.xs),
            Text(l.mealsTripHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Space.md),
            TripChoiceField(
              label: l.breakfast,
              value: _breakfast,
              options: MealStatus.values,
              optionLabel: mealLabel,
              onChanged: (v) => setState(() => _breakfast = v!),
            ),
            const SizedBox(height: Space.md),
            TripChoiceField(
              label: l.lunch,
              value: _lunch,
              options: MealStatus.values,
              optionLabel: mealLabel,
              onChanged: (v) => setState(() => _lunch = v!),
            ),
            const SizedBox(height: Space.md),
            TripChoiceField(
              label: l.dinner,
              value: _dinner,
              options: MealStatus.values,
              optionLabel: mealLabel,
              onChanged: (v) => setState(() => _dinner = v!),
            ),
            const SizedBox(height: Space.lg),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.notes, hintText: l.notesHint, alignLabelWithHint: true),
            ),
            const SizedBox(height: Space.lg),
            DraftDocumentsSection(draft: _documents),
          ],
        ),
      ),
    );
  }
}

/// What a trip needs to give a deduction, shown at the top of the form.
class _Requirements extends StatelessWidget {
  const _Requirements();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return NoteCard(
      title: l.requirementsTitle,
      bullets: [l.requirementOrdered, l.requirement50km, l.requirementOvernight],
      footer: l.requirementsConfirm,
    );
  }
}

/// A small (i) button that shows a longer explanation in a dialog, keeping
/// the form itself short.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.info_outline),
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      tooltip: l.moreInfo,
      onPressed: () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.close))],
        ),
      ),
    );
  }
}
