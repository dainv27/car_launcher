import 'package:car_launcher/core/auth/device_identity_service.dart';
import 'package:http/http.dart' as http;

/// Wraps an [http.Client] and attaches a fresh `X-Device-Assertion` JWS to every
/// request — the auth scheme for `vehicle-service`'s public device API.
///
/// On a 401 the cached assertion is dropped so the caller's retry mints a new
/// one (clock skew, a just-rotated key).
class DeviceAssertionClient extends http.BaseClient {
  DeviceAssertionClient({
    required http.Client inner,
    DeviceIdentityService? identity,
  })  : _inner = inner,
        _identity = identity ?? DeviceIdentityService.instance;

  final http.Client _inner;
  final DeviceIdentityService _identity;
  // ignore_for_file: prefer_initializing_formals

  static const String header = 'X-Device-Assertion';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers[header] = await _identity.assertion();
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      _identity.invalidateAssertion();
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
