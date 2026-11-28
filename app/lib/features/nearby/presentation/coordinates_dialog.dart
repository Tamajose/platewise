import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/widgets.dart';
import '../domain/restaurant.dart';
import '../../../core/l10n/l10n.dart';

/// A dialog for typing a latitude and longitude. Pops with the [GeoPoint].
class CoordinatesDialog extends StatefulWidget {
  const CoordinatesDialog(this.point, {super.key});
  final GeoPoint point;

  @override
  State<CoordinatesDialog> createState() => _CoordinatesDialogState();
}

class _CoordinatesDialogState extends State<CoordinatesDialog> {
  final form = GlobalKey<FormState>();
  late final TextEditingController latitude, longitude;

  @override
  void initState() {
    super.initState();
    latitude = TextEditingController(
      text: widget.point.latitude.toStringAsFixed(5),
    );
    longitude = TextEditingController(
      text: widget.point.longitude.toStringAsFixed(5),
    );
  }

  @override
  void dispose() {
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.tr('Enter coordinates')),
    scrollable: true,
    content: Form(
      key: form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in [
            (latitude, 'Latitude', 85),
            (longitude, 'Longitude', 180),
          ]) ...[
            TextFormField(
              controller: field.$1,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(labelText: context.tr(field.$2)),
              validator: (value) {
                final n = double.tryParse(value!.trim());
                return n == null || !n.isFinite || n.abs() > field.$3
                    ? context.tr('Enter –{p0} to {p1}.', {
                        'p0': field.$3,
                        'p1': field.$3,
                      })
                    : null;
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      PrimaryButton(
        context.tr('Use location'),
        onPressed: () {
          if (!form.currentState!.validate()) return;
          Navigator.pop(
            context,
            GeoPoint(
              double.parse(latitude.text.trim()),
              double.parse(longitude.text.trim()),
            ),
          );
        },
      ),
    ],
  );
}
