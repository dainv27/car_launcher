import 'package:car_launcher/core/config/env_loader.dart';

abstract final class ApiConfig {
  /// API gateway base URL.
  ///
  /// Resolution order:
  ///   1. `.env` / `.env.local` / `.env.<env>` (via flutter_dotenv)
  ///   2. `--dart-define=API_GATEWAY_BASE_URL=...` (compile-time)
  ///   3. Hardcoded default
  static String get apiGatewayUrl {
    const key = 'API_GATEWAY_BASE_URL';
    return EnvLoader.instance.getValue(key) ??
        const String.fromEnvironment(
          key,
          defaultValue: 'https://dev-car-apis.202corp.com',
        );
  }

  /// Route prefix the API gateway adds in front of `vehicle-service` (the
  /// service itself has no context path). Override with an empty value to hit a
  /// service running without the gateway, e.g. a local instance.
  static String get vehicleServiceBasePath {
    const key = 'VEHICLE_SERVICE_BASE_PATH';
    return EnvLoader.instance.getValue(key) ??
        const String.fromEnvironment(key, defaultValue: '/vehicle-service');
  }

  static String get vehicleServiceClientApiBaseUrl =>
      '$apiGatewayUrl$vehicleServiceBasePath/client-api/v1';

  /// Device self-service API (attestation / `X-Device-Assertion` auth, no
  /// Keycloak session). Sibling of the client API.
  static String get vehicleServicePublicApiBaseUrl =>
      '$apiGatewayUrl$vehicleServiceBasePath/public-api/v1';
}
