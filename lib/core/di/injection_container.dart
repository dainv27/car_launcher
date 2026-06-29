import 'package:car_launcher/shared/data/device_service.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:car_launcher/core/api/api_config.dart';
import 'package:car_launcher/core/logging/app_logger.dart';
import 'package:car_launcher/core/services/device_info_service.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/vehicle/data/tracking_repository.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_repository.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/vehicle_tracking_store_service.dart';
import 'package:car_launcher/shared/data/weather_service.dart';

/// Service locator for the application.
///
/// Wires concrete implementations into the get_it container so that
/// Riverpod providers can stay thin — they delegate to get_it rather
/// than constructing services themselves.
final GetIt getIt = GetIt.instance;

/// Initialises the service locator.
///
/// Must be called once from [main] before [runApp] so that singletons
/// are ready when providers first read them.
Future<void> setupServiceLocator() async {
  // ------------------------------------------------------------------
  //  Infrastructure singletons
  // ------------------------------------------------------------------

  // SharedPreferences — already initialised in main() before this call.
  // We register the live instance so providers can read it via getIt.
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);

  // AppLogger — classic Dart singleton. Migrating to get_it centralises
  // lifecycle management and removes the static-access anti-pattern.
  getIt.registerSingleton<AppLogger>(AppLogger.instance);

  // DeviceInfoService — classic Dart singleton. Same rationale as AppLogger.
  getIt.registerSingleton<DeviceInfoService>(DeviceInfoService.instance);

  // ------------------------------------------------------------------
  //  HTTP and auth
  // ------------------------------------------------------------------

  // KeycloakAuthRepository — manages OIDC session state. Semantically a
  // singleton (one auth session per app). Lazy because it calls
  // AppSecureStorage at construction and secure storage may need async
  // init.
  getIt.registerLazySingleton<KeycloakAuthRepository>(
    () => KeycloakAuthRepository(),
  );

  // http.Client (AuthInterceptorClient) — wraps a plain http.Client with
  // bearer-token injection. Lazy because it depends on KeycloakAuthRepository.
  getIt.registerLazySingleton<http.Client>(() {
    final auth = getIt<KeycloakAuthRepository>();
    final gatewayHost = Uri.parse(ApiConfig.apiGatewayUrl).host;
    return AuthInterceptorClient(
      inner: http.Client(),
      whitelist: {gatewayHost},
      accessTokenProvider: auth.accessToken,
      forceRefreshProvider: auth.forceRefreshToken,
    );
  });

  // ------------------------------------------------------------------
  //  Launcher and weather services
  // ------------------------------------------------------------------

  // LauncherService — facade over NativeBridge. Singleton because the
  // native bridge it wraps is inherently singleton.
  getIt.registerSingleton<LauncherService>(LauncherService(prefs));

  // WeatherService — stateless API wrapper. Lazy singleton because it holds
  // no mutable state and a single instance avoids unnecessary allocations.
  getIt.registerLazySingleton<WeatherService>(
    () => WeatherService(
      getIt<SharedPreferences>(),
      getIt<http.Client>(),
    ),
  );

  // ------------------------------------------------------------------
  //  Tracking and vehicle services
  // ------------------------------------------------------------------

  // VehicleTrackingStoreService — manages SQLite database. Lazy singleton
  // because database path resolution is async (uses NativeBridge +
  // path_provider). Must be singleton to avoid multiple concurrent
  // SQLite connections.
  getIt.registerLazySingleton<VehicleTrackingStoreService>(
    () => VehicleTrackingStoreService(),
  );

  // DeviceService — thin HTTP wrapper. Factory because it is
  // lightweight and has no mutable state beyond the injected http.Client.
  getIt.registerFactory<DeviceService>(
    () => DeviceService(httpClient: getIt<http.Client>()),
  );

  // VehicleTrackingSyncClient — thin HTTP wrapper. Factory because it is
  // lightweight and has no mutable state beyond the injected http.Client.
  getIt.registerFactory<VehicleTrackingSyncClient>(
    () => VehicleTrackingSyncClient(httpClient: getIt<http.Client>()),
  );

  // VehicleRepository — thin mapping layer. Factory because it has no
  // mutable state. We expose a parametric factory for the syncEndpoint
  // since it depends on runtime tracking state.
  getIt.registerFactoryParam<VehicleRepository, String, void>(
    (syncEndpoint, _) => VehicleRepository(
      syncClient: getIt<VehicleTrackingSyncClient>(),
      syncEndpoint: syncEndpoint,
    ),
  );

  // TrackingRepository — thin wrapper combining sync client + SQLite
  // store. Factory with parametric syncEndpoint for the same reason.
  getIt.registerFactoryParam<TrackingRepository, String, void>(
    (syncEndpoint, _) => TrackingRepository(
      syncClient: getIt<VehicleTrackingSyncClient>(),
      store: getIt<VehicleTrackingStoreService>(),
      syncEndpoint: syncEndpoint,
    ),
  );
}

/// A [http.BaseClient] wrapper that injects `Authorization: Bearer <token>`
/// only when the request host is in [whitelist].
///
/// Token resolution and force-refresh are deferred to callbacks so this
/// client stays agnostic of how the token is stored.Construction lives in
/// [setupServiceLocator] so callbacks can wire to [KeycloakAuthRepository].
class AuthInterceptorClient extends http.BaseClient {
  AuthInterceptorClient({
    required this.inner,
    required this.whitelist,
    this.accessTokenProvider,
    this.forceRefreshProvider,
  });

  /// The underlying HTTP client.
  final http.Client inner;

  /// Hosts for which the bearer token is injected.
  final Set<String> whitelist;

  /// Resolves the current access token (may return null).
  final Future<String?> Function()? accessTokenProvider;

  /// Forces a token refresh; returns true if a fresh token is available.
  final Future<bool> Function()? forceRefreshProvider;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isWhitelisted = whitelist.contains(request.url.host);

    Future<http.StreamedResponse> sendWithToken(String? token) async {
      if (isWhitelisted && token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Content-Type'] = 'application/json';

      return inner.send(request);
    }

    final token = await accessTokenProvider?.call();
    final response = await sendWithToken(token);

    if (isWhitelisted && response.statusCode == 401) {
      final refreshed = await forceRefreshProvider?.call() ?? false;
      if (refreshed) {
        final retryToken = await accessTokenProvider?.call();
        return _sendWithTokenOnCopy(request, retryToken);
      }
    }
    return response;
  }

  Future<http.StreamedResponse> _sendWithTokenOnCopy(
    http.BaseRequest original,
    String? token,
  ) async {
    final copy = _copyRequest(original);
    if (token != null && token.isNotEmpty) {
      copy.headers['Authorization'] = 'Bearer $token';
    }
    return inner.send(copy);
  }

  http.BaseRequest _copyRequest(http.BaseRequest original) {
    http.BaseRequest request;
    if (original is http.Request) {
      request = http.Request(original.method, original.url)
        ..body = original.body
        ..encoding = original.encoding;
    } else if (original is http.MultipartRequest) {
      final multipart = http.MultipartRequest(original.method, original.url)
        ..fields.addAll(original.fields)
        ..files.addAll(original.files);
      request = multipart;
    } else if (original is http.StreamedRequest) {
      // Cannot re-stream — fall back to a simple request on the same URL.
      request = http.Request(original.method, original.url);
    } else {
      request = http.Request(original.method, original.url);
    }
    request.headers.addAll(original.headers);
    return request;
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}
