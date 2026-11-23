import '../core/domain/overview.dart';
import '../core/presentation/routes.dart';

/// Where the app opens, given what the service knows about the person: the
/// settings screen while a data deletion is pending, the welcome screen until
/// a profile exists, and Today otherwise.
String entryRoute(Overview overview) => overview.deletionPending
    ? Routes.settings
    : overview.profile == null
    ? Routes.welcome
    : Routes.today;
