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
