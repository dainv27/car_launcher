import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_point.dart';
import 'package:car_launcher/features/vehicle/domain/tracking_route.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/map_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/tracking_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/views/tracking_history_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const routeKey = (vehicleId: 'car-001', from: null, to: null);
  const historyKey = ('car-001', null, null);

  List<Override> overrides({
    List<TrackingPoint> points = const [],
    TrackingRoute route = const TrackingRoute(),
    bool authenticated = true,
  }) {
    return [
      vehicleRouteProvider(routeKey).overrideWith((_) async => route),
      trackingHistoryProvider(historyKey).overrideWith((_) async => points),
      accountSessionProvider.overrideWith(
        () => authenticated ? _AuthenticatedNotifier() : _UnauthenticatedNotifier(),
      ),
    ];
  }

  Widget appWith(List<Override> o) => ProviderScope(
        overrides: o,
        child: const MaterialApp(
          home: TrackingHistoryPage(vehicleId: 'car-001'),
        ),
      );

  group('TrackingHistoryPage', () {
    testWidgets('renders app bar with title and back button', (tester) async {
      await tester.pumpWidget(appWith(overrides()));
      await tester.pumpAndSettle();

      expect(find.text('Tracking History'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(find.byKey(const Key('tracking-history-date-range')), findsOneWidget);
    });

    testWidgets('map view shows an empty-route message by default',
        (tester) async {
      await tester.pumpWidget(appWith(overrides()));
      await tester.pumpAndSettle();

      expect(find.text('No route for this range'), findsOneWidget);
    });

    testWidgets('switching to list view renders tracking points',
        (tester) async {
      final points = [
        TrackingPoint(
          id: 'p-1',
          latitude: 10.0,
          longitude: 106.0,
          speedKph: 50.0,
          heading: 180.0,
          eventTime: DateTime.parse('2026-06-22T12:00:00.000Z'),
        ),
        TrackingPoint(
          id: 'p-2',
          latitude: 11.0,
          longitude: 107.0,
          speedKph: 60.0,
          heading: 90.0,
          eventTime: DateTime.parse('2026-06-22T13:00:00.000Z'),
        ),
      ];
      await tester.pumpWidget(appWith(overrides(points: points)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      expect(find.text('10.000000, 106.000000'), findsOneWidget);
      expect(find.text('11.000000, 107.000000'), findsOneWidget);
      expect(find.text('50.0 km/h'), findsOneWidget);
      expect(find.text('60.0 km/h'), findsOneWidget);
    });

    testWidgets('list view shows empty state when no points', (tester) async {
      await tester.pumpWidget(appWith(overrides()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.list));
      await tester.pumpAndSettle();

      expect(find.text('No tracking points yet'), findsOneWidget);
    });

    testWidgets('renders login-required gate when unauthenticated',
        (tester) async {
      await tester.pumpWidget(appWith(overrides(authenticated: false)));
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.text('Tracking history'), findsOneWidget);
    });
  });
}

class _AuthenticatedNotifier extends AccountNotifier {
  @override
  Future<AccountUser?> build() async => const AccountUser(
        id: 'u-1',
        email: 'tester@example.com',
        displayName: 'Tester',
        preferredLocale: 'vi',
        authProvider: AccountAuthProvider.email,
      );
}

class _UnauthenticatedNotifier extends AccountNotifier {
  @override
  Future<AccountUser?> build() async => null;
}
