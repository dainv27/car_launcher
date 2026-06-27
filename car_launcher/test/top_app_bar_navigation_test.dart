import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/features/account/repositories/keycloak_auth_repository.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/widgets/top_app_bar.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/media/data/media_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A clock notifier that always returns a fixed short time string.
class _FixedClock extends ClockNotifier {
  _FixedClock() : super();

  @override
  String get state => '1:23';

  @override
  set state(String value) {}
}

GoRouter _buildTestRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _TestHostPage(),
      ),
      GoRoute(
        path: '/media',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Media'))),
      ),
      GoRoute(
        path: '/navigation',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Navigation'))),
      ),
      GoRoute(
        path: '/apps',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Apps'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Settings'))),
      ),
    ],
  );
}

/// A page that renders TopAppBar inside a Scaffold so it gets proper layout.
class _TestHostPage extends StatelessWidget {
  const _TestHostPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          TopAppBar(),
          Expanded(child: SizedBox.expand()),
        ],
      ),
    );
  }
}

Future<Widget> _buildWideShell(GoRouter router) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final launcher = LauncherService(prefs);

  return ProviderScope(
    overrides: [
      currentLocationProvider.overrideWith((ref) => LocationNotifier()),
      mediaAccessProvider.overrideWith((_) => Stream.value(false)),
      connectivityStatusProvider.overrideWith(
        (ref) => ConnectivityNotifier(
          launcher,
          const Stream<Map<String, dynamic>>.empty(),
        ),
      ),
      clockProvider.overrideWith((ref) => _FixedClock()),
      vehicleTrackingProvider.overrideWith(
        (ref) => VehicleTrackingNotifier(
          KeycloakAuthRepository(),
          syncClient: _NoOpSyncClient(),
          loadPersisted: false,
        ),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('TopAppBar renders navigation menu on wide screens',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top-bar-navigation-menu')), findsOneWidget);
    expect(find.byKey(const Key('top-bar-nav-media')), findsOneWidget);
    expect(find.byKey(const Key('top-bar-nav-navigation')), findsOneWidget);
    expect(find.byKey(const Key('top-bar-nav-apps')), findsOneWidget);
    expect(find.byKey(const Key('top-bar-nav-settings')), findsOneWidget);
  });

  testWidgets('TopAppBar hides navigation menu on compact screens',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('top-bar-navigation-menu')), findsNothing);
    expect(find.byKey(const Key('top-bar-clock')), findsOneWidget);
    expect(find.byKey(const Key('top-bar-tracking-dot')), findsOneWidget);
  });

  testWidgets('tapping Media in the nav menu pushes /media route',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-bar-nav-media')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/media');
  });

  testWidgets('tapping Navigation in the nav menu pushes /navigation route',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-bar-nav-navigation')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/navigation');
  });

  testWidgets('tapping Apps in the nav menu pushes /apps route',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-bar-nav-apps')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/apps');
  });

  testWidgets('tapping Settings in the nav menu pushes /settings route',
      (tester) async {
    final router = _buildTestRouter('/');

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(await _buildWideShell(router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('top-bar-nav-settings')));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/settings');
  });
}

/// No-op sync client that does nothing (for widget tests).
class _NoOpSyncClient extends VehicleTrackingSyncClient {
  _NoOpSyncClient() : super(httpClient: _StubHttpClient());

  @override
  Future<void> sync({
    required String endpoint,
    required List<VehicleTrackPoint> points,
    VehicleProfile vehicle = const VehicleProfile(),
  }) async {}

  @override
  Future<void> ensureDeviceRegistered() async {}
}

class _StubHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream<List<int>>.value(const []),
      200,
    );
  }
}
