class AppConfig {
  const AppConfig({
    this.mode = const String.fromEnvironment(
      'PLATEWISE_MODE',
      defaultValue: 'demo',
    ),
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.publishableKey = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    this.localDevelopment = const bool.fromEnvironment('PLATEWISE_LOCAL_DEV'),
    this.protectedMapTiles = const bool.fromEnvironment('PLATEWISE_OSM_TILES'),
  });
  final String mode, url, publishableKey;
  final bool localDevelopment, protectedMapTiles;
  bool get demo => mode == 'demo';
  bool get canConnect {
    final target = Uri.tryParse(url);
    if (mode != 'live' ||
        publishableKey.isEmpty ||
        target == null ||
        target.host.isEmpty ||
        target.userInfo.isNotEmpty ||
        (target.path.isNotEmpty && target.path != '/')) {
      return false;
    }
    return target.scheme == 'https' ||
        (localDevelopment &&
            target.scheme == 'http' &&
            ['localhost', '127.0.0.1', '10.0.2.2'].contains(target.host));
  }
}
