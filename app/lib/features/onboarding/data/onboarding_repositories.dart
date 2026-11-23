import '../../../core/data/demo/demo_foods.dart';
import '../../../core/data/demo/demo_store.dart';
import '../../../core/data/ids.dart';
import '../../../core/domain/domain.dart';
import '../domain/onboarding_repository.dart';

/// A live build starts with a real, empty profile. There is no sample day.
class LiveOnboardingRepository implements OnboardingRepository {
  const LiveOnboardingRepository();

  @override
  bool get offersSampleDay => false;

  @override
  Future<void> startSampleDay() async {
    throw const Failure('A sample day is only available in demo mode.');
  }
}

/// Demo mode can fill the log with five illustrative days over the last week.
class DemoOnboardingRepository implements OnboardingRepository {
  DemoOnboardingRepository(
    this._store, {
    this._generateId = newId,
    this._now = _utcNow,
  });

  final DemoStore _store;
  final IdGenerator _generateId;
  final DateTime Function() _now;

  @override
  bool get offersSampleDay => true;

  @override
  Future<void> startSampleDay() async {
    final now = _now();
    final local = localTime(now, 'Asia/Dhaka');
    const foods = [DemoFoods.eggs, DemoFoods.khichuri, DemoFoods.chicken];
    final meals = <SavedMeal>[];
    final water = <WaterEntry>[];
    for (final offset in [0, -1, -3, -4, -6]) {
      final moment = local.subtract(Duration(hours: 24 * -offset));
      for (var i = 0; i < (offset == 0 ? 3 : 2 + (-offset % 2)); i++) {
        final timestamp = moment.subtract(Duration(minutes: i * 27)).toUtc();
        final draft = MealDraft(
          id: _generateId(),
          source: MealSource.manual,
          items: [foods[(i - offset) % foods.length]],
          assumptions: const ['Illustrative sample day.'],
          model: 'demo-fixtures',
        );
        meals.add(
          SavedMeal(
            draft,
            timestamp,
            timestamp.toIso8601String(),
            draft.range.midpoint,
          ),
        );
      }
      water.add(
        WaterEntry(
          _generateId(),
          moment.toUtc(),
          offset == 0 ? 750 : 1250,
          now.toIso8601String(),
        ),
      );
    }
    await _store.update(
      (_) => Overview(
        profile: const Profile(height: 170, weight: 69, target: 2050),
        meals: meals,
        water: water,
        targets: [
          TargetSnapshot(dayKey(dayAt(local, -6)), 1950),
          TargetSnapshot(dayKey(dayAt(local, -3)), 2050),
        ],
        sampleHistory: true,
      ),
    );
  }
}

DateTime _utcNow() => DateTime.now().toUtc();
