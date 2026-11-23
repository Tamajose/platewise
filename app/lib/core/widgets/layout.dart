import 'package:material_ui/material_ui.dart';

import '../theme/plate_theme.dart';

class PageScroll extends StatelessWidget {
  const PageScroll({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding,
    this.maxWidth = 610,
  });
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets? padding;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final insets = constraints.maxWidth >= 720
            ? const EdgeInsets.fromLTRB(32, 30, 32, 36)
            : const EdgeInsets.fromLTRB(18, 18, 18, 26);
        final list = ListView(
          padding: padding ?? insets,
          physics: onRefresh == null
              ? null
              : const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
        return onRefresh == null
            ? list
            : RefreshIndicator(onRefresh: onRefresh!, child: list);
      },
    ),
  );
}

class AdaptiveColumns extends StatelessWidget {
  const AdaptiveColumns({
    super.key,
    required this.primary,
    required this.secondary,
    this.primaryFlex = 3,
    this.secondaryFlex = 2,
    this.breakpoint = 720,
  });
  final Widget primary, secondary;
  final int primaryFlex, secondaryFlex;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final wide =
          size.maxWidth >= breakpoint &&
          MediaQuery.textScalerOf(context).scale(14) <= 20;
      return Flex(
        direction: wide ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: wide
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: wide ? primaryFlex : 0, child: primary),
          SizedBox(width: wide ? 20 : 0, height: wide ? 0 : 14),
          Expanded(flex: wide ? secondaryFlex : 0, child: secondary),
        ],
      );
    },
  );
}

class Standalone extends StatelessWidget {
  const Standalone({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.actions,
  });
  final String title;
  final Widget body;
  final Widget? bottom;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: body,
    bottomNavigationBar: bottom == null ? null : BottomAction(child: bottom!),
  );
}

class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: PlateColors.canvas,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 9, 20, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 610),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    ),
  );
}

class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.color = PlateColors.surface,
    this.padding = const EdgeInsets.all(16),
    this.border = PlateColors.line,
  });
  final Widget child;
  final Color color, border;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: child,
  );
}
