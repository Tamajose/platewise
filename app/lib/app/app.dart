import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/data/core_providers.dart';
import '../core/domain/dates.dart';
import '../core/presentation/routes.dart';
import '../features/auth/data/account_providers.dart';
import '../features/auth/domain/account_rules.dart';
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
  String? userId;

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

  /// Starts the app again when a different person signs in, or the person
  /// signs out, so nothing from the previous account stays on screen.
  void userChanged(String? next) {
    final previous = userId;
    userId = next;
    if (!resetsOnUserChange(previous, next)) return;
    ref.invalidate(overviewProvider);
    ref.invalidate(capabilitiesProvider);
    ref.invalidate(accountProvider);
    ref.read(routerProvider).go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userChangesProvider, (_, next) => next.whenData(userChanged));
    return MaterialApp.router(
      title: 'PlateWise',
      debugShowCheckedModeBanner: false,
      theme: plateTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
