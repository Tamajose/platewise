import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/media_storage.dart';
import '../domain/overview_repository.dart';
import '../domain/photo_picker.dart';
import '../domain/profile_repository.dart';
import '../domain/session_repository.dart';
import 'ids.dart';

/// Overridden by the composition root with the demo or live implementation.
final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => throw StateError('Session repository initialization required'),
);

/// Overridden by the composition root with the demo or live implementation.
final overviewRepositoryProvider = Provider<OverviewRepository>(
  (ref) => throw StateError('Overview repository initialization required'),
);

/// Overridden by the composition root with the demo or live implementation.
final mediaStorageProvider = Provider<MediaStorage>(
  (ref) => throw StateError('Media storage initialization required'),
);

/// Overridden by the composition root with the device implementation.
final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => throw StateError('Photo picker initialization required'),
);

/// The signed-in user's ID each time it changes, null when signed out. Demo
/// mode has no sessions, so the default never emits. The live composition
/// overrides it with the auth service's change stream.
final userChangesProvider = StreamProvider<String?>(
  (ref) => const Stream.empty(),
);

/// Tests override this to get predictable identifiers.
final idGeneratorProvider = Provider<IdGenerator>((ref) => newId);

/// Opens a link in the browser or another app. Returns whether it opened.
/// Tests override this.
final urlOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => launchUrl,
);

/// Overridden by the composition root with the demo or live implementation.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw StateError('Profile repository initialization required'),
);
