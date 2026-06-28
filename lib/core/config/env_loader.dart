import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads environment variables from `.env.*` files at runtime.
///
/// Priority (later overrides earlier):
///   1. `.env` — base defaults, always loaded
///   2. `.env.local` — local overrides (gitignored)
///   3. `.env.<env>` — environment-specific (development / production)
///
/// After [load] completes, access values via [dotenv.env] or the typed
/// getters on [ApiConfig] / [KeycloakConfig].
class EnvLoader {
  EnvLoader._();

  static final EnvLoader instance = EnvLoader._();

  /// True after [load] has completed successfully.
  bool _loaded = false;
  bool get loaded => _loaded;

  /// Load env files. Safe to call multiple times — only the first call does
  /// the work.
  Future<void> load({String environment = 'development'}) async {
    if (_loaded) return;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Base file is optional — continue.
    }

    try {
      await dotenv.load(fileName: '.env.local');
    } catch (_) {
      // Local overrides are optional.
    }

    if (environment != 'development') {
      try {
        await dotenv.load(fileName: '.env.$environment');
      } catch (_) {
        // Environment-specific file is optional.
      }
    }

    _loaded = true;
  }

  /// Read a value with an optional fallback.
  String? getValue(String key, [String? fallback]) =>
      dotenv.env[key] ?? fallback;
}
