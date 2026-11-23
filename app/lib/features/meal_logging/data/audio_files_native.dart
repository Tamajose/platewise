import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> audioPath(String name) async =>
    '${(await getTemporaryDirectory()).path}/$name';

Future<void> forgetAudio(String? path) async {
  if (path == null) return;
  final file = File(path);
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    /* The operating system clears temporary storage. */
  }
}
