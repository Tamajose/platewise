import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/routes.dart';
import '../../../core/theme/plate_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../data/export_providers.dart';
import '../domain/stats_export.dart';
import 'export_controller.dart';

const _presets = [
  (label: '1 week', days: 7),
  (label: '1 month', days: 30),
  (label: '3 months', days: 90),
  (label: '6 months', days: 180),
  (label: '1 year', days: 365),
];

/// Export daily statistics for a chosen stretch of days as a CSV file.
class ExportScreen extends ConsumerWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allowed = ref.watch(exportPermissionProvider).value ?? false;
    final state = ref.watch(exportControllerProvider);
    final controller = ref.read(exportControllerProvider.notifier);
    final result = state.result;
    final style = Theme.of(context).textTheme;
    return Standalone(
      title: 'Export stats',
      body: PageScroll(
        children: [
          const PageHeading(
            'Export your stats',
            detail: 'Daily calorie estimates, targets and water as a spreadsheet file.',
          ),
          const SizedBox(height: 20),
          if (!allowed) ...[
            const Surface(
              child: Text(
                'Exporting is off. A file leaves the protection of the app, so PlateWise asks first. You can turn it off again under Data and privacy in Settings.',
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              'Allow data export',
              icon: Icons.lock_open_rounded,
              onPressed: () =>
                  ref.read(exportPermissionProvider.notifier).set(true),
            ),
            TextButton(
              onPressed: () => context.push(Routes.settings),
              child: const Text('Open Settings'),
            ),
          ] else ...[
            Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Period', style: style.titleMedium),
                  const SizedBox(height: 4),
                  Text('Last ${state.days} days', style: style.headlineSmall),
                  Slider(
                    value: state.days.toDouble(),
                    min: minExportDays.toDouble(),
                    max: maxExportDays.toDouble(),
                    divisions: maxExportDays - minExportDays,
                    label: '${state.days} days',
                    semanticFormatterCallback: (v) => '${v.round()} days',
                    onChanged: state.busy
                        ? null
                        : (v) => controller.setDays(v.round()),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in _presets)
                        ChoiceChip(
                          label: Text(preset.label),
                          selected: state.days == preset.days,
                          onSelected: state.busy
                              ? null
                              : (_) => controller.setDays(preset.days),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'From one week to one year. Days before your first record are left out.',
                    style: style.bodySmall?.copyWith(color: PlateColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (state.error != null) ...[
              ErrorState(state.error!),
              const SizedBox(height: 10),
            ],
            PrimaryButton(
              'Prepare export',
              icon: Icons.table_chart_outlined,
              busy: state.busy,
              onPressed: controller.prepare,
            ),
            if (state.busy) const LoadingState('Gathering your records…'),
            if (result != null) ...[
              const SizedBox(height: 16),
              _Summary(result),
              const SizedBox(height: 12),
              PrimaryButton(
                'Save CSV file',
                icon: Icons.download_rounded,
                onPressed: controller.save,
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                'Copy to clipboard',
                icon: Icons.copy_rounded,
                onPressed: controller.copy,
              ),
            ],
            if (state.notice != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Surface(child: Text(state.notice!)),
              ),
            ],
          ],
          const SizedBox(height: 18),
          const DisclaimerNotice(
            text: 'Calories are estimates shown as ranges. The file holds personal health information, so keep it somewhere private.',
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.result);
  final StatsExport result;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ready to export', style: style.titleMedium),
          const SizedBox(height: 6),
          Text(
            '${result.days} days · ${result.loggedDays} with meals · ${result.mealCount} meals',
          ),
          if (result.shortened) ...[
            const SizedBox(height: 6),
            Text(
              'You asked for ${result.requestedDays} days, but your records cover ${result.availableDays}, so the file holds ${result.days}.',
              style: style.bodySmall?.copyWith(color: PlateColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
