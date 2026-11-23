import '../domain/failure.dart';

/// The message to show a person for [error]. Known failures carry their own
/// message. Anything else gets a generic, safe message.
String failureMessage(Object error) => messageFor(error);
