import 'package:material_ui/material_ui.dart';

import '../domain/photo_picker.dart';
import '../../core/l10n/l10n.dart';

/// Asks whether to use the camera or the gallery. Null when dismissed.
Future<PhotoSource?> choosePhotoSource(BuildContext context) =>
    showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.tr('Use camera')),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('Choose from gallery')),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
