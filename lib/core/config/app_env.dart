/// Runtime environment identification.
///
/// The environment name comes from the `APP_ENV` compile-time define
/// (`--dart-define=APP_ENV=...`). This mirrors how [main] resolves the
/// environment and how `.env.<env>` files are selected, so a build compiled
/// for production reports `production` here even before the `.env` files load.
abstract final class AppEnv {
  /// Active environment name. Defaults to `development` when `APP_ENV` is not
  /// supplied at build time.
  static const String name =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// True for every build that was not explicitly compiled for production.
  ///
  /// Used to gate verbose diagnostics (e.g. full HTTP request/response
  /// tracing for the vehicle service) so they run on `develop` but stay off
  /// in release builds.
  static bool get isDevelopment => name != 'production';
}
