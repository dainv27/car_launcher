import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:openidconnect_linux/openidconnect_linux.dart';
import 'package:openidconnect_platform_interface/openidconnect_platform_interface.dart';
import 'package:openidconnect_windows/openidconnect_windows.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:car_launcher/core/auth/app_secure_storage.dart';

/// MethodChannel for native → Flutter OAuth redirect communication.
const _oauthChannel = MethodChannel('com.carlauncher/oauth');

/// Configure platform-specific OIDC before login.
///
/// On Android: uses external browser (not Custom Tab). The OAuth redirect
/// goes through the system browser → intent-filter on MainActivity →
/// onNewIntent → processOAuthCallback → MethodChannel → completeLogin().
/// On Windows/Linux: uses loopback HTTP server.
void configureKeycloakOidcPlatform() {
  // Set up MethodChannel handler for OAuth redirects from native
  _oauthChannel.setMethodCallHandler((call) async {
    if (call.method == 'onOAuthRedirect') {
      final uri = call.arguments as String?;
      if (uri != null) {
        handleOAuthRedirect(uri);
      }
    }
  });
  if (kIsWeb) return;
  if (Platform.isWindows) {
    OpenIdConnectPlatform.instance = _CarLauncherOpenIdConnectPlatform(
      OpenIdConnectWindows(launchUrl: _launchOAuthUrlOnWindows),
      launchUrl: _launchOAuthUrlOnWindows,
    );
    return;
  }
  if (Platform.isLinux) {
    OpenIdConnectPlatform.instance = _CarLauncherOpenIdConnectPlatform(
      OpenIdConnectLinux(),
      launchUrl: _launchOAuthUrlOnLinux,
    );
  }
  // Android: set custom platform that uses external browser
  if (Platform.isAndroid) {
    OpenIdConnectPlatform.instance = _CarLauncherAndroidOpenIdConnectPlatform(
      launchUrl: _launchOAuthUrlOnAndroid,
    );
  }
}

void cancelKeycloakInteractiveLogin() {
  _CarLauncherOpenIdConnectPlatform.cancelInteractiveLogin();
  final completer = _pendingOAuthCompleter;
  if (completer != null && !completer.isCompleted) {
    completer.completeError(StateError('User cancelled OAuth login'));
  }
  _pendingOAuthCompleter = null;
}

// ════════════════════════════════════════════════════════════════════════════
// Android: external browser (not Custom Tab)
// ════════════════════════════════════════════════════════════════════════════

/// Global reference to the pending OAuth completer.
/// When the external browser redirects back, the Flutter side receives
/// the redirect URI via MethodChannel and completes this completer.
Completer<String>? _pendingOAuthCompleter;
String? _startupOAuthRedirect;

/// Called from native MainActivity when OAuth redirect is received.
void handleOAuthRedirect(String redirectUri) {
  final completer = _pendingOAuthCompleter;
  if (completer != null && !completer.isCompleted) {
    completer.complete(redirectUri);
    _pendingOAuthCompleter = null;
  } else {
    _startupOAuthRedirect = redirectUri;
  }
}

class _CarLauncherAndroidOpenIdConnectPlatform extends OpenIdConnectPlatform {
  _CarLauncherAndroidOpenIdConnectPlatform({required this._launchUrl});

  final Future<void> Function(String url) _launchUrl;

  @override
  Future<String?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useWebRedirectLoop = false,
  }) async {
    // Create a completer that will be resolved when the OAuth redirect arrives
    if (_pendingOAuthCompleter != null) {
      throw StateError('OAuth login is already in progress');
    }
    _pendingOAuthCompleter = Completer<String>();

    // Open external browser
    await _launchUrl(authorizationUrl);

    // Wait for the redirect URI to arrive via handleOAuthRedirect()
    // Timeout after 2 minutes
    final redirectUri = await _pendingOAuthCompleter!.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _pendingOAuthCompleter = null;
        throw StateError('OAuth login timed out');
      },
    );
    return redirectUri;
  }

  @override
  Future<String?> processStartup() async {
    final redirect = _startupOAuthRedirect;
    _startupOAuthRedirect = null;
    return redirect;
  }

  @override
  Future<void> secureStorageInitialize() async {}

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) => AppSecureStorage.instance.write(key: key, value: value);

  @override
  Future<String?> secureStorageRead({required String key}) =>
      AppSecureStorage.instance.read(key: key);

  @override
  Future<void> secureStorageDelete({required String key}) =>
      AppSecureStorage.instance.delete(key: key);

  @override
  Future<bool> secureStorageContainsKey({required String key}) =>
      AppSecureStorage.instance.containsKey(key: key);
}

Future<void> _launchOAuthUrlOnAndroid(String url) async {
  final uri = Uri.parse(url);
  // Force external browser — NOT Custom Tab
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    // Fallback: try without specifying mode
    await launchUrl(uri);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Desktop (Windows/Linux): loopback HTTP server
// ════════════════════════════════════════════════════════════════════════════

class _CarLauncherOpenIdConnectPlatform extends OpenIdConnectPlatform {
  _CarLauncherOpenIdConnectPlatform(this._inner, {required this._launchUrl});

  final OpenIdConnectPlatform _inner;
  final DesktopUrlLauncher _launchUrl;

  static Completer<void>? _cancelCompleter;

  static void cancelInteractiveLogin() {
    final pending = _cancelCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  static void _beginInteractiveLogin() {
    _cancelCompleter = Completer<void>();
  }

  static void _endInteractiveLogin() {
    _cancelCompleter = null;
  }

  @override
  Future<String?> authorizeInteractive({
    required BuildContext context,
    required String title,
    required String authorizationUrl,
    required String redirectUrl,
    required int popupWidth,
    required int popupHeight,
    bool useWebRedirectLoop = false,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux) {
      return _inner.authorizeInteractive(
        context: context,
        title: title,
        authorizationUrl: authorizationUrl,
        redirectUrl: redirectUrl,
        popupWidth: popupWidth,
        popupHeight: popupHeight,
        useWebRedirectLoop: useWebRedirectLoop,
      );
    }

    _beginInteractiveLogin();
    try {
      return await _desktopLoopbackAuth(
        authorizationUrl: authorizationUrl,
        redirectUrl: redirectUrl,
        launchUrl: _launchUrl,
        cancelSignal: _cancelCompleter!.future,
      );
    } finally {
      _endInteractiveLogin();
    }
  }

  @override
  Future<String?> processStartup() => _inner.processStartup();

  @override
  Future<void> secureStorageInitialize() => _inner.secureStorageInitialize();

  @override
  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) => _inner.secureStorageWrite(key: key, value: value);

  @override
  Future<String?> secureStorageRead({required String key}) =>
      _inner.secureStorageRead(key: key);

  @override
  Future<void> secureStorageDelete({required String key}) =>
      _inner.secureStorageDelete(key: key);

  @override
  Future<bool> secureStorageContainsKey({required String key}) =>
      _inner.secureStorageContainsKey(key: key);
}

typedef DesktopUrlLauncher = Future<void> Function(String url);

Future<String> _desktopLoopbackAuth({
  required String authorizationUrl,
  required String redirectUrl,
  required DesktopUrlLauncher launchUrl,
  required Future<void> cancelSignal,
  Duration timeout = const Duration(minutes: 2),
}) async {
  final uri = Uri.parse(redirectUrl);
  final path = uri.path.isEmpty ? '/*' : uri.path;

  if (uri.scheme != 'http' ||
      uri.host != 'localhost' ||
      !uri.hasPort ||
      uri.port <= 0) {
    throw StateError(
      'Desktop OAuth needs redirect http://localhost:<port>/path. Got: $redirectUrl',
    );
  }

  HttpServer? server;
  StreamSubscription<HttpRequest>? subscription;

  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, uri.port);
    final redirectCompleter = Completer<String>();

    subscription = server.listen(
      (request) {
        unawaited(
          _handleLoopbackRequest(
            request: request,
            path: path,
            redirectCompleter: redirectCompleter,
          ),
        );
      },
      onError: redirectCompleter.completeError,
      cancelOnError: true,
    );

    await launchUrl(authorizationUrl);

    final redirectFuture = redirectCompleter.future;
    final result =
        await Future.any<String>([
          redirectFuture,
          cancelSignal.then(
            (_) => throw AuthenticationException(ERROR_USER_CLOSED),
          ),
        ]).timeout(
          timeout,
          onTimeout: () => throw AuthenticationException(ERROR_USER_CLOSED),
        );

    return result;
  } on SocketException catch (e) {
    throw AuthenticationException(
      'Cannot open loopback port http://localhost:${uri.port}. ${e.message}',
    );
  } on ProcessException catch (e) {
    throw AuthenticationException('Cannot open OAuth browser. ${e.message}');
  } finally {
    await subscription?.cancel();
    await server?.close(force: true);
  }
}

Future<void> _handleLoopbackRequest({
  required HttpRequest request,
  required String path,
  required Completer<String> redirectCompleter,
}) async {
  if (request.method != 'GET') {
    request.response.statusCode = HttpStatus.methodNotAllowed;
    await request.response.close();
    return;
  }

  final requestedUri = request.requestedUri;
  if (path != '/*' && requestedUri.path != path) {
    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
    return;
  }

  request.response.statusCode = HttpStatus.ok;
  request.response.headers.contentType = ContentType.html;
  request.response.write(_loopbackCompleteHtml);
  await request.response.close();

  if (!redirectCompleter.isCompleted) {
    redirectCompleter.complete(requestedUri.toString());
  }
}

const _loopbackCompleteHtml = '''
<!DOCTYPE html>
<html lang="vi">
<head><meta charset="utf-8"><title>Login</title></head>
<body><p>Login complete. You can close this tab and return to Car Launcher.</p></body>
</html>
''';

Future<void> _launchOAuthUrlOnWindows(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;
  }
  final result = await Process.run('cmd.exe', [
    '/c',
    'start',
    '',
    url,
  ], runInShell: false);
  if (result.exitCode != 0) {
    throw ProcessException(
      'cmd.exe',
      ['/c', 'start'],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}

Future<void> _launchOAuthUrlOnLinux(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched) return;
  }
  final result = await Process.run('xdg-open', [url]);
  if (result.exitCode != 0) {
    throw ProcessException(
      'xdg-open',
      [url],
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}
