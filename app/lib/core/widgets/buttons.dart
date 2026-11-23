import 'package:material_ui/material_ui.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: busy ? null : onPressed,
    child: _ButtonContent(label, icon: icon, busy: busy),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: _ButtonContent(label, icon: icon),
  );
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent(this.label, {this.icon, this.busy = false});
  final String label;
  final IconData? icon;
  final bool busy;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (busy)
        const Padding(
          padding: EdgeInsets.only(right: 8),
          child: SizedBox.square(
            dimension: 17,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      else if (icon != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Icon(icon, size: 19),
        ),
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ],
  );
}
