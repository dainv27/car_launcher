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

  static String get vehicleServiceClientApiBaseUrl =>
      '$apiGatewayUrl/vehicle-service/client-api/v1';
}
