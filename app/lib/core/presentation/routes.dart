/// Route paths. Features navigate by path, so they never import `app/`, where
/// the router maps each path to a screen.
abstract final class Routes {
  static const home = '/';
  static const log = '/log';
  static const review = '/review';
  static const decide = '/decide';
  static const menuReview = '/menu-review';
  static const today = '/today';
  static const nearby = '/nearby';
  static const progress = '/progress';
  static const welcome = '/welcome';
  static const settings = '/settings';
  static const water = '/water';
  static const profile = '/profile';

  /// The person's own page: details, account and sign out.
  static const me = '/me';
  static const account = '/account';
  static const export = '/export';
  static const energy = '/energy';
  static const credits = '/credits';
  static const correction = '/correction';
  static const signIn = '/account?mode=signin';
}
