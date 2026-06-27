abstract final class ApiConfig {
  static const apiGatewayUrl = String.fromEnvironment(
    'API_GATEWAY_BASE_URL',
    defaultValue: 'https://dev-car-apis.202corp.com',
  );

  static const vehicleServiceClientApiBaseUrl = '$apiGatewayUrl/vehicle-service/client-api/v1';
}
