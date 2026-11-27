import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Offers [text] to the person as a file download. Returns where it went.
Future<String> saveExport(String name, String text) async {
  final blob = web.Blob(
    [text.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(link);
  link.click();
  link.remove();
  web.URL.revokeObjectURL(url);
  return 'your browser downloads';
}
