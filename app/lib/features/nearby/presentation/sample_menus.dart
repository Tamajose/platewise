import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/data/core_providers.dart';
import '../../../core/domain/domain.dart';
import '../../../core/presentation/failure_message.dart';
import '../../../core/presentation/review_args.dart';
import '../../../core/presentation/routes.dart';
import '../../../core/presentation/session_state.dart';
import '../../../core/widgets/widgets.dart';
import '../data/nearby_providers.dart';
import '../domain/nearby_meal.dart';
import '../domain/nearby_services.dart';
import '../domain/restaurant.dart';
import '../../../core/l10n/l10n.dart';

typedef _Area = ({GeoPoint point, double radius});

final _sampleMealsProvider = FutureProvider.autoDispose
    .family<List<NearbyMeal>, _Area>((ref, area) {
      final budget = suggestedBudget(ref.watch(overviewProvider).value);
      return ref
          .watch(nearbyRepositoryProvider)
          .sampleMeals(area.point, area.radius, budget);
    });

/// Illustrative meals from seeded menus around [point], shown in demo mode.
class SampleMenus extends ConsumerWidget {
  const SampleMenus({super.key, required this.point, required this.radius});
  final GeoPoint point;
  final double radius;

  Future<void> choose(
    BuildContext context,
    WidgetRef ref,
    NearbyMeal meal,
  ) async {
    final draft = draftForNearbyMeal(meal, ref.read(idGeneratorProvider)());
    final saved = await context.push<bool>(
      Routes.review,
      extra: ReviewArgs(draft),
    );
    if (saved == true && context.mounted) context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = _sampleMealsProvider((point: point, radius: radius));
    final samples = ref.watch(request);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          context.tr('Sample meal suggestions'),
          detail: context.tr(
            'Illustrative menus and portions from fictional venues.',
          ),
        ),
        const SizedBox(height: 7),
        if (samples.isLoading)
          LoadingState(context.tr('Loading sample meals…')),
        if (samples.hasError)
          ErrorState(
            failureMessage(samples.error!),
            retry: () => ref.invalidate(request),
          ),
        if (samples.value?.isEmpty ?? false)
          EmptyState(
            context.tr('No sample meals available'),
            context.tr('Try a larger radius or choose Cumilla Town Hall.'),
            icon: Icons.location_off_outlined,
          ),
        for (final meal in samples.value ?? <NearbyMeal>[]) ...[
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconTile(Icons.restaurant_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            meal.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            context.tr('{p0} · {p1} km', {
                              'p0': meal.restaurant,
                              'p1': meal.distance.toStringAsFixed(1),
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('{p0} kcal · {p1}', {
                    'p0': meal.range.label,
                    'p1': meal.portion,
                  }),
                ),
                const SizedBox(height: 6),
                BudgetFitBadge(meal.fit),
                const SizedBox(height: 5),
                TextButton(
                  onPressed: () => choose(context, ref, meal),
                  child: Text(context.tr('Review this meal')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 8),
        const DisclaimerNotice(),
      ],
    );
  }
}
