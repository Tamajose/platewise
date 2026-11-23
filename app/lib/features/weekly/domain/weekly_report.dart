import '../../../core/domain/domain.dart';

typedef WeeklySummary = ({String state, List<String> sentences});

class WeeklyReport {
  WeeklyReport(this.days);
  final List<DayLog> days;
  Iterable<DayLog> get logged => days.where((d) => d.logged);
  Iterable<DayLog> get paired => logged.where((d) => d.target != null);
  int get overlap => paired.where((d) => d.targetRelation == 'Overlaps').length;
  int? get average => logged.isEmpty
      ? null
      : (logged.fold(0, (sum, d) => sum + d.representative) / logged.length)
            .round();
  int? get targetAverage => paired.isEmpty
      ? null
      : (paired.fold(0, (sum, d) => sum + d.target!) / paired.length).round();
  Iterable<FoodItem> get items =>
      days.expand((d) => d.meals).expand((m) => m.draft.items);
  List<String> get facts => logged.length < 2
      ? []
      : [
          'You logged meals on ${logged.length} of 7 days.',
          'Logged intake averaged about $average kcal on those days.',
          if (paired.isNotEmpty)
            'The recorded calorie range overlapped the target on $overlap of ${paired.length} logged days with a target.',
          if (days.any((d) => d.waterMl > 0))
            'You logged water on ${days.where((d) => d.waterMl > 0).length} of 7 days.',
        ];
}
