import 'package:flutter/material.dart';

import 'format.dart';

/// A tappable field showing a wall-clock date and time (UTC-mode DateTime, see
/// trakta_core's WallTime). Opens a date picker, then a 24-hour time picker.
class DateTimeField extends StatelessWidget {
  const DateTimeField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  Future<void> _pick(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(value.year, value.month, value.day),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time == null) return;
    onChanged(DateTime.utc(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event)),
        child: Text(formatWall(context, value)),
      ),
    );
  }
}

/// A tappable field for a calendar date only.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2015),
          lastDate: DateTime(2100),
        );
        if (date != null) onChanged(DateTime(date.year, date.month, date.day));
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.event)),
        child: Text(MaterialLocalizations.of(context).formatMediumDate(value)),
      ),
    );
  }
}
