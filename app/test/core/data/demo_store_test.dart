import 'package:flutter_test/flutter_test.dart';
import 'package:platewise/core/data/demo/demo_store.dart';
import 'package:platewise/core/domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Overview withProfile(double weight) =>
    Overview(profile: Profile(height: 170, weight: weight, target: 1800));

void main() {
  late SharedPreferencesAsync preferences;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
  });

  test('starts empty', () async {
    final overview = await DemoStore(preferences).read();
    expect(overview.profile, isNull);
    expect(overview.meals, isEmpty);
  });

  test('the storage key matches earlier builds', () {
    expect(DemoStore.key, 'platewise.demo.v1');
  });

  test('changes are saved and found by a new store', () async {
    await DemoStore(preferences).update((_) => withProfile(70));
    final revived = await DemoStore(preferences).read();
    expect(revived.profile!.weight, 70);
    expect(revived.profile!.target, 1800);
  });

  test('a store reads its own latest change', () async {
    final store = DemoStore(preferences);
    await store.update((_) => withProfile(71));
    expect((await store.read()).profile!.weight, 71);
  });

  test('overlapping updates run in order on the latest state', () async {
    final store = DemoStore(preferences);
    final seen = <double?>[];
    final first = store.update((current) {
      seen.add(current.profile?.weight);
      return withProfile(60);
    });
    final second = store.update((current) {
      seen.add(current.profile?.weight);
      return withProfile(61);
    });
    await Future.wait([first, second]);
    expect(seen, [null, 60]);
    expect((await store.read()).profile!.weight, 61);
  });

  test('a failing update surfaces and does not block later ones', () async {
    final store = DemoStore(preferences);
    await expectLater(
      store.update((_) => throw StateError('rejected')),
      throwsStateError,
    );
    await store.update((_) => withProfile(65));
    expect((await store.read()).profile!.weight, 65);
  });

  test('unreadable stored data is treated as empty', () async {
    await preferences.setString(DemoStore.key, '{not json');
    expect((await DemoStore(preferences).read()).profile, isNull);
  });

  test('stored data of the wrong shape is treated as empty', () async {
    await preferences.setString(DemoStore.key, '[1,2,3]');
    expect((await DemoStore(preferences).read()).meals, isEmpty);
  });
}
