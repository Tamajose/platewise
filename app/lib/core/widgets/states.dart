import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';
import 'indicators.dart';
import 'layout.dart';
import '../../core/l10n/l10n.dart';

class LoadingState extends StatelessWidget {
  const LoadingState(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(context.tr(message))),
        ],
      ),
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState(this.message, {super.key, this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Surface(
      color: PlateColors.amber,
      border: const Color(0xFFE9D7AC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: PlateColors.amberInk,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.tr(message),
                  style: const TextStyle(color: PlateColors.amberInk),
                ),
              ),
            ],
          ),
          if (retry != null)
            TextButton(onPressed: retry, child: Text(context.tr('Try again'))),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.ramen_dining_outlined,
  });
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Surface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                container: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                message,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: PlateColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
