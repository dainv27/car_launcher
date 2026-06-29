import 'api_config.dart';

class UrlUtils {
  static Uri vehicleUri(String? endpoint, String relativePath, {Map<String, String>? queryParameters}) {
    final base = _vehicleServiceBase(endpoint ?? '');
    return base.replace(
      pathSegments: [
        ...base.pathSegments.where((segment) => segment.isNotEmpty),
        ...relativePath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters,
    );
  }

  static Uri _vehicleServiceBase(String endpoint) {
    if (endpoint.trim().isEmpty) {
      return Uri.parse(ApiConfig.vehicleServiceClientApiBaseUrl);
    }
    final uri = Uri.parse(endpoint.trim());
    final segments = uri.pathSegments;
    final serviceIndex = segments.indexOf('vehicle-service');
    if (serviceIndex < 0) return uri;

    final versionIndex = segments.indexOf('v1', serviceIndex);
    final pathSegments = versionIndex < 0
        ? [...segments.take(serviceIndex + 1), 'client-api', 'v1']
        : segments.take(versionIndex + 1).toList(growable: false);

    return Uri(
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: pathSegments,
    );
  }
}
