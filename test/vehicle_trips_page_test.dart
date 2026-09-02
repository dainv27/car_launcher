import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/vehicle/domain/trip.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/trip_providers.dart';
import 'package:car_launcher/features/vehicle/presentation/views/vehicle_trips_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const query = (
    vehicleId: 'car-001',
    from: null,
    to: null,
    status: null,
  );

  Widget appWith(List<Override> overrides) => ProviderScope(
        overrides: [
          accountSessionProvider.overrideWith(() => _Authed()),
          ...overrides,
        ],
        child: const MaterialApp(
          home: VehicleTripsPage(vehicleId: 'car-001'),
        ),
      );

  testWidgets('shows empty state when there are no trips', (tester) async {
    await tester.pumpWidget(appWith([
      tripListProvider(query).overrideWith((ref) async => const <Trip>[]),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('No trips in this view'), findsOneWidget);
  });

  testWidgets('renders a trip row with distance + duration', (tester) async {
    final trip = Trip(
      id: 't-1',
      status: TripStatus.closed,
      startTime: DateTime.parse('2026-06-22T08:00:00.000Z'),
      distanceMeters: 8300,
      durationSeconds: 1500,
      avgSpeedKph: 20,
    );
    await tester.pumpWidget(appWith([
      tripListProvider(query).overrideWith((ref) async => [trip]),
    ]));
    await tester.pumpAndSettle();

    expect(find.textContaining('8.3 km'), findsOneWidget);
    expect(find.textContaining('25m'), findsOneWidget);
  });
}

class _Authed extends AccountNotifier {
  @override
  Future<AccountUser?> build() async => const AccountUser(
        id: 'u-1',
        email: 't@example.com',
        displayName: 'T',
        preferredLocale: 'vi',
        authProvider: AccountAuthProvider.email,
      );
}
