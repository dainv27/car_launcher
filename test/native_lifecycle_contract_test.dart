import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final mainActivity = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
  );
  final appRouter = File('lib/core/router/app_router.dart');

  test('OAuth callbacks support cold and warm delivery without URI logging', () {
    final source = mainActivity.readAsStringSync();
    final routerSource = appRouter.readAsStringSync();

    expect(source, contains('processOAuthCallback(intent)'));
    expect(source, contains('override fun onNewIntent(intent: Intent)'));
    expect(source, contains('pendingOAuthCallback'));
    expect(source, contains('flushPendingOAuthCallback'));
    expect(routerSource, contains("return '/';"));
    expect(routerSource, contains("return '/login';"));
    expect(routerSource, isNot(contains('handleOAuthRedirect(uri.toString())')));
  });

  test('OAuth login waits for the S60 callback before cancelling', () {
    final loginPage = File(
      'lib/features/account/presentation/views/account_login_page.dart',
    ).readAsStringSync();

    expect(loginPage, contains('Duration(seconds: 5)'));
    expect(loginPage, isNot(contains('Duration(milliseconds: 700)')));
    expect(loginPage, contains("context.go('/')"));
  });

  test('main activity deterministically releases native listeners and channels', () {
    final source = mainActivity.readAsStringSync();

    expect(source, contains('override fun onDestroy()'));
    expect(source, contains('unregisterConnectivityReceiver()'));
    expect(source, contains('unregisterMediaSessionListener()'));
    expect(source, contains('setMethodCallHandler(null)'));
    expect(source, contains('setStreamHandler(null)'));
  });

  test('native activity no longer accepts sidebar route requests', () {
    final activity = mainActivity.readAsStringSync();

    expect(activity, isNot(contains('processRouteRequest')));
    expect(activity, isNot(contains('"onRouteRequest"')));
    expect(activity, isNot(contains('pendingRouteRequest')));
  });
}
