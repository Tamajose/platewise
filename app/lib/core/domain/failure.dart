/// What to tell a person when something went wrong that we cannot describe.
const genericFailureMessage =
    'PlateWise could not finish that request. Check your connection and try again.';

/// The message to show for [error]: a [Failure] carries its own, anything
/// else gets [genericFailureMessage].
String messageFor(Object error) =>
    error is Failure ? error.message : genericFailureMessage;

/// A failure the domain can describe without knowing where it came from.
/// Data sources translate transport and provider errors into this type.
class Failure implements Exception {
  const Failure(
    this.message, {
    this.code = 'UNAVAILABLE',
    this.retryable = false,
    this.requestId,
  });
  final String message, code;
  final bool retryable;
  final String? requestId;
  @override
  String toString() => message;
}
