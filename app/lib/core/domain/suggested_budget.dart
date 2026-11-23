import 'overview.dart';

/// The calories left today, or null when there is no target or none is left.
int? suggestedBudget(Overview? overview) {
  final log = overview?.today;
  final target = log?.target;
  if (target == null || log == null) return null;
  final remaining = target - log.representative;
  return remaining > 0 ? remaining : null;
}
