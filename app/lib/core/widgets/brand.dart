import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';

class PlateMark extends StatelessWidget {
  const PlateMark({super.key, this.size = 34});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: PlateColors.deep,
      borderRadius: BorderRadius.circular(size * .29),
    ),
    child: Icon(Icons.eco_outlined, color: PlateColors.lime, size: size * .65),
  );
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 80) {
        final size = constraints.maxWidth.clamp(0.0, 34.0);
        return Semantics(
          label: 'PlateWise',
          child: Align(
            alignment: Alignment.centerLeft,
            child: PlateMark(size: size),
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PlateMark(),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              'PlateWise',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(letterSpacing: -.7, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      );
    },
  );
}
