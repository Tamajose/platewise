import 'package:uuid/uuid.dart';

typedef IdGenerator = String Function();

const _uuid = Uuid();

/// A new random identifier for drafts and storage objects.
String newId() => _uuid.v4();
