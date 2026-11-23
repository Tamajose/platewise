import 'package:timezone/timezone.dart' as tz;

/// The calendar day of [date] as `yyyy-mm-dd`.
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Converts a UTC instant to wall-clock time in the IANA time [zone].
/// Requires the timezone database to be initialized.
DateTime localTime(DateTime value, String zone) =>
    tz.TZDateTime.from(value, tz.getLocation(zone));

/// Midnight UTC of [local]'s calendar day, shifted by [offset] days.
DateTime dayAt(DateTime local, [int offset = 0]) =>
    DateTime.utc(local.year, local.month, local.day + offset);
