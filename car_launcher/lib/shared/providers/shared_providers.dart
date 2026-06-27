import 'package:car_launcher/core/api/api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';

/// Provider for shared preferences (we need to define this if not already)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences provider must be overridden');
});

/// Provider for [AuthInterceptorClient] — injects bearer token only for
/// whitelisted hosts.
final httpClientProvider = Provider<http.Client>((ref) {
  final auth = ref.watch(keycloakAuthRepositoryProvider);
  final gatewayHost = Uri.parse(ApiConfig.apiGatewayUrl).host;
  return AuthInterceptorClient(
    inner: http.Client(),
    whitelist: {gatewayHost},
    accessTokenProvider: auth.accessToken,
    forceRefreshProvider: auth.forceRefreshToken,
  );
});

/// A [http.BaseClient] wrapper that injects `Authorization: Bearer <token>`
/// only when the request host is in [whitelist].
///
/// Token resolution and force-refresh are deferred to callbacks so this
/// client stays agnostic of how the token is stored.
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

  /// Re-build a copy of [original] and send with [token] for 401 retry.
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

  /// Create a copy of [original] so it can be sent again after a 401 retry.
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
      // This path is unlikely for vehicle API calls.
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
