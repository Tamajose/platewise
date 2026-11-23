import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';

class FoodPicture extends StatelessWidget {
  const FoodPicture({
    super.key,
    this.bytes,
    this.url,
    this.editorial = false,
    this.height = 155,
  });
  final Uint8List? bytes;
  final String? url;
  final bool editorial;
  final double height;
  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: PlateColors.sage,
      child: Center(
        child: Icon(
          Icons.ramen_dining_outlined,
          size: 42,
          color: PlateColors.forest.withValues(alpha: .72),
        ),
      ),
    );
    Widget error(BuildContext _, Object _, StackTrace? _) => placeholder;
    final w = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.cover, errorBuilder: error)
        : url != null
        ? Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: error,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
          )
        : editorial
        ? Image.asset(
            'assets/images/platewise-hero.webp',
            fit: BoxFit.cover,
            alignment: const Alignment(.28, 0),
            excludeFromSemantics: true,
            errorBuilder: error,
          )
        : placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(height: height, width: double.infinity, child: w),
    );
  }
}
