const minPasswordLength = 10;

const signInInputMessage = 'Enter your account email and password.';
const emailMessage = 'Enter a valid email address.';
const passwordLengthMessage = 'Use at least $minPasswordLength characters.';

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Whether [text] looks like an email address. The service decides whether it
/// is really deliverable.
bool isValidEmail(String text) => _email.hasMatch(text.trim());

/// Whether the app should drop what it loaded and start again when the signed
/// in person changes from [previous] to [next]. The first sign-in, which opens
/// the anonymous guest session, does not.
bool resetsOnUserChange(String? previous, String? next) =>
    next != previous && !(previous == null && next != null);
