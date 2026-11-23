/// Changes to the daily log that Today offers.
abstract interface class TodayRepository {
  /// Deletes a logged meal and any photo saved with it.
  Future<void> deleteMeal(String id);
}
