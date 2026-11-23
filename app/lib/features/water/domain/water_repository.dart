import '../../../core/domain/day_log.dart';

/// The most water one entry may hold, in millilitres.
const maxWaterEntryMl = 2000;

const waterAmountMessage = 'Enter 1–$maxWaterEntryMl ml.';

/// An amount from typed text, or null when it is not a whole number of
/// millilitres from 1 to 2,000.
int? parseWaterAmount(String text) {
  final value = int.tryParse(text.trim());
  return value == null || value < 1 || value > maxWaterEntryMl ? null : value;
}

abstract interface class WaterRepository {
  /// Adds an entry, or changes the one with [id] when [revision] is given.
  /// Saving the same new [id] twice keeps one entry, so a retry after a lost
  /// reply cannot double count. Throws a `Failure` when the entry changed or
  /// was removed since it was read.
  Future<WaterEntry> save(String id, int amount, {String? revision});

  Future<void> remove(String id);
}
