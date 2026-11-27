import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [text] to the downloads folder where the platform has one, and to the
/// app's documents folder otherwise. Returns the path.
Future<String> saveExport(String name, String text) async {
  Directory? folder;
  try {
    folder = await getDownloadsDirectory();
  } on Object {
    folder = null;
  }
  folder ??= await getApplicationDocumentsDirectory();
  final file = File('${folder.path}${Platform.pathSeparator}$name');
  await file.writeAsString(text, flush: true);
  return file.path;
}
