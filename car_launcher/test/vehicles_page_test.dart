import 'package:car_launcher/features/account/presentation/providers/account_providers.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/presentation/views/vehicles_page.dart';
import 'package:car_launcher/features/vehicle/presentation/providers/vehicle_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VehiclesPage', () {
    testWidgets('renders empty state when no vehicles', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleListProvider.overrideWith(() => _EmptyVehicleListNotifier()),
            accountSessionProvider.overrideWith(() => _AuthenticatedNotifier()),
          ],
          child: const MaterialApp(
            home: VehiclesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No vehicles registered'), findsOneWidget);
      expect(find.text('Tap + to add your first vehicle'), findsOneWidget);
      expect(find.byKey(const Key('vehicles-add-fab')), findsOneWidget);
    });

    testWidgets('renders vehicle list when vehicles exist', (tester) async {
      final vehicles = [
        const Vehicle(
          id: 'car-001',
          plateNumber: '51A-12345',
          name: 'Family car',
          brand: 'Toyota',
          model: 'Vios',
          metadata: {'year': '2026'},
        ),
        const Vehicle(
          id: 'car-002',
          plateNumber: '59B-99999',
          name: 'Work car',
          brand: 'Honda',
          model: 'Civic',
        ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleListProvider.overrideWith(
              () => _StubVehicleListNotifier(vehicles),
            ),
            accountSessionProvider.overrideWith(() => _AuthenticatedNotifier()),
          ],
          child: const MaterialApp(
            home: VehiclesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('51A-12345'), findsOneWidget);
      expect(find.text('59B-99999'), findsOneWidget);
      expect(find.byKey(const Key('vehicles-add-fab')), findsOneWidget);
    });

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleListProvider.overrideWith(() => _EmptyVehicleListNotifier()),
            accountSessionProvider.overrideWith(() => _AuthenticatedNotifier()),
          ],
          child: const MaterialApp(
            home: VehiclesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicles'), findsOneWidget);
    });

    testWidgets('renders login-required gate when unauthenticated',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vehicleListProvider.overrideWith(() => _EmptyVehicleListNotifier()),
            accountSessionProvider.overrideWith(() => _UnauthenticatedNotifier()),
          ],
          child: const MaterialApp(
            home: VehiclesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in required'), findsOneWidget);
      expect(find.text('Manage vehicles'), findsOneWidget);
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

/// Stub notifier that returns an empty vehicle list.
class _EmptyVehicleListNotifier extends AsyncNotifier<List<Vehicle>>
    implements VehicleListNotifier {
  @override
  Future<List<Vehicle>> build() async => const [];

  @override
  Future<void> refresh() async {}

  @override
  Future<Vehicle> createVehicle(Vehicle vehicle) async => vehicle;
}

/// Stub notifier that returns a predefined vehicle list.
class _StubVehicleListNotifier extends AsyncNotifier<List<Vehicle>>
    implements VehicleListNotifier {
  _StubVehicleListNotifier(this._vehicles);

  final List<Vehicle> _vehicles;

  @override
  Future<List<Vehicle>> build() async => _vehicles;

  @override
  Future<void> refresh() async {}

  @override
  Future<Vehicle> createVehicle(Vehicle vehicle) async => vehicle;
}
