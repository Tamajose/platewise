import '../domain/failure.dart';

/// The message to show a person for [error]. Known failures carry their own
/// message. Anything else gets a generic, safe message.
String failureMessage(Object error) => error is Failure
    ? error.message
    : 'PlateWise could not finish that request. Check your connection and try again.';
