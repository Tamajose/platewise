import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/domain/dates.dart';
import '../core/presentation/session_state.dart';
import '../core/theme/plate_theme.dart';
import 'router.dart';

/// The application shell: theme, routing, and the day rollover check.
class PlateWiseApp extends ConsumerStatefulWidget {
  const PlateWiseApp({super.key});

  @override
  ConsumerState<PlateWiseApp> createState() => _PlateWiseAppState();
}

class _PlateWiseAppState extends ConsumerState<PlateWiseApp>
    with WidgetsBindingObserver {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(minutes: 1), (_) => checkDay());
  }

  /// Refreshes the log when midnight passed while the app stayed open.
  void checkDay() {
    final cached = ref.read(overviewProvider).value;
    if (cached == null || cached.profile == null) return;
    final now = dayKey(localTime(DateTime.now(), cached.zone));
    if (now != dayKey(cached.todayDate)) ref.invalidate(overviewProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkDay();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'PlateWise',
    debugShowCheckedModeBanner: false,
    theme: plateTheme(),
    routerConfig: ref.watch(routerProvider),
  );
}
