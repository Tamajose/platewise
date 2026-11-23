/// On the web the recorder keeps audio in the browser, so there is no file.
Future<String> audioPath(String name) async => name;

Future<void> forgetAudio(String? path) async {}
