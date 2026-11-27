import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/failure_message.dart';
import '../data/export_providers.dart';
import '../data/settings_providers.dart';
import '../domain/stats_export.dart';

class ExportState {
  const ExportState({
    this.days = 30,
    this.busy = false,
    this.result,
    this.error,
    this.notice,
  });

  final int days;
  final bool busy;
  final StatsExport? result;
  final String? error, notice;

  ExportState copyWith({
    int? days,
    bool? busy,
    StatsExport? result,
    String? error,
    String? notice,
    bool clearResult = false,
    bool clearMessages = false,
  }) => ExportState(
    days: days ?? this.days,
    busy: busy ?? this.busy,
    result: clearResult ? null : result ?? this.result,
    error: clearMessages ? null : error ?? this.error,
    notice: clearMessages ? null : notice ?? this.notice,
  );
}

/// Choosing how many days to export, preparing them and handing them over.
class ExportController extends Notifier<ExportState> {
  @override
  ExportState build() => const ExportState();

  /// Chooses the number of days, kept between a week and a year. A new choice
  /// clears any export prepared for the old one.
  void setDays(int days) => state = state.copyWith(
    days: days.clamp(minExportDays, maxExportDays),
    clearResult: true,
    clearMessages: true,
  );

  Future<void> prepare() async {
    if (state.busy) return;
    if (!(ref.read(exportPermissionProvider).value ?? false)) {
      state = state.copyWith(
        error: 'Turn on data export under Data and privacy first.',
      );
      return;
    }
    state = state.copyWith(busy: true, clearResult: true, clearMessages: true);
    try {
      final result = await ref
          .read(settingsRepositoryProvider)
          .exportStats(state.days);
      if (ref.mounted) state = state.copyWith(busy: false, result: result);
    } on Object catch (e) {
      if (ref.mounted) {
        state = state.copyWith(busy: false, error: failureMessage(e));
      }
    }
  }

  Future<void> save() async {
    final result = state.result;
    if (result == null) return;
    try {
      final where = await ref.read(saveExportProvider)(
        result.fileName,
        result.toCsv(),
      );
      if (ref.mounted) {
        state = state.copyWith(notice: 'Saved ${result.fileName} to $where.');
      }
    } on Object catch (e) {
      if (ref.mounted) state = state.copyWith(error: failureMessage(e));
    }
  }

  Future<void> copy() async {
    final result = state.result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.toCsv()));
    if (ref.mounted) {
      state = state.copyWith(notice: 'Copied the CSV to the clipboard.');
    }
  }
}

final exportControllerProvider =
    NotifierProvider.autoDispose<ExportController, ExportState>(
      ExportController.new,
    );
