import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';
import 'layout.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.detail,
  });
  final String label, value;
  final String? detail;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge
              ?.copyWith(color: PlateColors.muted),
        ),
        const SizedBox(height: 5),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        if (detail != null)
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
