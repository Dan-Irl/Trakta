import 'package:trakta_core/trakta_core.dart';

import '../../l10n/app_localizations.dart';
import '../common/format.dart';

String expenseKindLabel(AppLocalizations l, CommuteExpenseKind k) => switch (k) {
      CommuteExpenseKind.congestionTax => l.expCongestion,
      CommuteExpenseKind.roadToll => l.expRoad,
      CommuteExpenseKind.bridgeToll => l.expBridge,
      CommuteExpenseKind.ferryFee => l.expFerry,
      CommuteExpenseKind.parking => l.expParking,
    };

String recurrenceLabel(AppLocalizations l, ExpenseRecurrence r) => switch (r) {
      ExpenseRecurrence.once => l.recOnce,
      ExpenseRecurrence.monthly => l.recMonthly,
      ExpenseRecurrence.perCommuteDay => l.recPerDay,
    };

String noCommuteReasonLabel(AppLocalizations l, NoCommuteReason r) => switch (r) {
      NoCommuteReason.vacation => l.reasonVacation,
      NoCommuteReason.sick => l.reasonSick,
      NoCommuteReason.homeOffice => l.reasonHomeOffice,
      NoCommuteReason.other => l.reasonOther,
    };

String holidayName(AppLocalizations l, SwedishHoliday h) => switch (h) {
      SwedishHoliday.newYearsDay => l.hNewYearsDay,
      SwedishHoliday.epiphany => l.hEpiphany,
      SwedishHoliday.goodFriday => l.hGoodFriday,
      SwedishHoliday.easterSunday => l.hEasterSunday,
      SwedishHoliday.easterMonday => l.hEasterMonday,
      SwedishHoliday.mayDay => l.hMayDay,
      SwedishHoliday.ascensionDay => l.hAscensionDay,
      SwedishHoliday.whitSunday => l.hWhitSunday,
      SwedishHoliday.nationalDay => l.hNationalDay,
      SwedishHoliday.midsummerEve => l.hMidsummerEve,
      SwedishHoliday.midsummerDay => l.hMidsummerDay,
      SwedishHoliday.allSaintsDay => l.hAllSaintsDay,
      SwedishHoliday.christmasEve => l.hChristmasEve,
      SwedishHoliday.christmasDay => l.hChristmasDay,
      SwedishHoliday.boxingDay => l.hBoxingDay,
      SwedishHoliday.newYearsEve => l.hNewYearsEve,
    };

/// "Mon–Fri" style list of weekdays, e.g. "Mon, Tue, Thu".
String weekdaysLabel(AppLocalizations l, Set<int> days) =>
    [for (final d in days.toList()..sort()) weekdayShort(l, d)].join(', ');

/// Kilometres from metres, whole km unless there is a fraction.
String kmText(AppLocalizations l, int metres) => formatDecimal(l.localeName, metres / 1000);
