import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import '../theme/plate_theme.dart';

class IndicatorTag extends StatelessWidget {
  const IndicatorTag(
    this.label, {
    super.key,
    this.icon,
    this.foreground = PlateColors.forest,
    this.background = PlateColors.sage,
  });
  final String label;
  final IconData? icon;
  final Color foreground, background;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ),
  );
}

class DisclaimerNotice extends StatelessWidget {
  const DisclaimerNotice({
    super.key,
    this.text = 'PlateWise provides general nutrition estimates and is not medical advice.',
  });
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(
        Icons.info_outline_rounded,
        size: 17,
        color: PlateColors.muted,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          context.tr(text),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: PlateColors.muted),
        ),
      ),
    ],
  );
}

class IconTile extends StatelessWidget {
  const IconTile(
    this.icon, {
    super.key,
    this.color = PlateColors.sage,
    this.ink = PlateColors.forest,
  });
  final IconData icon;
  final Color color, ink;
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, size: 20, color: ink),
  );
}
