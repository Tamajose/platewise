import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';

class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    super.key,
    required this.title,
    required this.message,
    required this.action,
    this.danger = false,
  });
  final String title, message, action;
  final bool danger;
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool danger = false,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ConfirmationSheet(
          title: title,
          message: message,
          action: action,
          danger: danger,
        ),
      ) ??
      false;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 9),
          Text(message),
          const SizedBox(height: 18),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(backgroundColor: PlateColors.red)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
