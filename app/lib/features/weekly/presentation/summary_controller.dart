import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/failure_message.dart';
import '../data/weekly_providers.dart';
import '../domain/weekly_report.dart';

class SummaryState {
  const SummaryState({this.summary, this.loading = false, this.error});
  final WeeklySummary? summary;
  final bool loading;
  final String? error;
}

/// Asks for the AI summary of one week. The key is the week's facts, so a
/// change to the log starts a fresh, ungenerated summary.
class SummaryController extends Notifier<SummaryState> {
  SummaryController(this.weekKey);

  final String weekKey;

  @override
  SummaryState build() => const SummaryState();

  Future<void> generate() async {
    if (state.loading) return;
    state = const SummaryState(loading: true);
    try {
      final summary = await ref.read(weeklyRepositoryProvider).summary();
      if (ref.mounted) state = SummaryState(summary: summary);
    } on Object catch (e) {
      if (ref.mounted) state = SummaryState(error: failureMessage(e));
    }
  }
}

final summaryControllerProvider = NotifierProvider.autoDispose
    .family<SummaryController, SummaryState, String>(SummaryController.new);
