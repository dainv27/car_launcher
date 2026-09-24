import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:car_launcher/core/di/injection_container.dart';

/// Provider for shared preferences — bridges get_it singleton into Riverpod.
///
/// The singleton is guaranteed registered in main() before ProviderScope is
/// created, so this provider is a thin accessor.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => getIt<SharedPreferences>(),
);

/// Provider for [http.Client] — bridges get_it lazySingleton into Riverpod.
///
/// The [AuthInterceptorClient] is constructed inside injection_container.dart
/// with bearer-token injection wired to [KeycloakAuthRepository]. Falls back to
/// a plain client when the DI container has not been booted (widget tests that
/// pump a screen in isolation), so accessor providers do not throw at build
/// time; production always has the singleton registered.
final httpClientProvider = Provider<http.Client>(
  (ref) => getIt.isRegistered<http.Client>() ? getIt<http.Client>() : http.Client(),
);
