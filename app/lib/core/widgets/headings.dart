import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.detail, this.trailing});
  final String title;
  final String? detail;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
      if (detail != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            detail!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: PlateColors.muted),
          ),
        ),
    ],
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title, {
    super.key,
    this.detail,
    this.eyebrow,
    this.prominent = false,
  });
  final String title;
  final String? detail, eyebrow;
  final bool prominent;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: t.labelLarge?.copyWith(color: PlateColors.forest),
          ),
          const SizedBox(height: 6),
        ],
        Semantics(
          container: true,
          header: true,
          child: Text(
            title,
            style: prominent ? t.displayMedium : t.headlineLarge,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 7),
          Text(
            detail!,
            style: (prominent ? t.bodyLarge : t.bodyMedium)?.copyWith(
              color: PlateColors.muted,
            ),
          ),
        ],
      ],
    );
  }
}
