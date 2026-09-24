import 'dart:io';

import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/features/vehicle/domain/vehicle.dart';
import 'package:car_launcher/features/vehicle/data/vehicle_api_client.dart';
import 'package:car_launcher/features/vehicle/presentation/widgets/vehicle_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

Future<void> _pumpDialog(
  WidgetTester tester,
  Future<void> Function(Vehicle) onSubmit, {
  ValueChanged<Vehicle?>? onClosed,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dayTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await showDialog<Vehicle?>(
                context: context,
                builder: (_) => VehicleFormDialog(onSubmit: onSubmit),
              );
              onClosed?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('vehicle-form-plate')),
    '30A-999.01',
  );
  await tester.enterText(find.byKey(const Key('vehicle-form-name')), 'Car');
}

void main() {
  group('VehicleServiceException.fromResponse', () {
    test('prefers the server message', () {
      final error = VehicleServiceException.fromResponse(
        http.Response('{"message":"Plate number already exists"}', 409),
        'Could not register the vehicle',
      );
      expect(error.statusCode, 409);
      expect(error.message, 'Plate number already exists');
    });

    test('falls back when the body is not JSON', () {
      final error = VehicleServiceException.fromResponse(
        http.Response('<html>Bad gateway</html>', 502),
        'Could not register the vehicle',
      );
      expect(error.message, 'Could not register the vehicle (HTTP 502)');
    });
  });

  group('describeVehicleError', () {
    test('uses the connectivity hint only for network failures', () {
      expect(
        describeVehicleError(const SocketException('down')),
        contains('Could not reach the vehicle service'),
      );
      expect(
        describeVehicleError(StateError('boom')),
        'Something went wrong: Bad state: boom',
      );
    });
  });

  testWidgets('a rejected save keeps the dialog open with the reason', (
    tester,
  ) async {
    Vehicle? closedWith;
    var closed = false;
    await _pumpDialog(
      tester,
      (_) async => throw const VehicleServiceException(
        409,
        'Plate number already exists',
      ),
      onClosed: (v) {
        closed = true;
        closedWith = v;
      },
    );
    await _fillRequired(tester);

    await tester.tap(find.byKey(const Key('vehicle-form-save')));
    await tester.pumpAndSettle();

    expect(closed, isFalse);
    expect(find.byKey(const Key('vehicle-form-error')), findsOneWidget);
    expect(find.text('Plate number already exists'), findsOneWidget);
    // What the driver typed is still there.
    expect(find.text('30A-999.01'), findsOneWidget);
    expect(closedWith, isNull);
  });

  testWidgets('a successful save closes the dialog with the vehicle', (
    tester,
  ) async {
    Vehicle? submitted;
    Vehicle? closedWith;
    await _pumpDialog(
      tester,
      (vehicle) async => submitted = vehicle,
      onClosed: (v) => closedWith = v,
    );
    await _fillRequired(tester);

    await tester.tap(find.byKey(const Key('vehicle-form-save')));
    await tester.pumpAndSettle();

    expect(submitted?.plateNumber, '30A-999.01');
    expect(closedWith?.name, 'Car');
    expect(find.byType(VehicleFormDialog), findsNothing);
  });

  testWidgets('only touched fields show "Required"', (tester) async {
    await _pumpDialog(tester, (_) async {});

    await tester.enterText(find.byKey(const Key('vehicle-form-plate')), 'x');
    await tester.enterText(find.byKey(const Key('vehicle-form-plate')), '');
    await tester.pump();

    // The plate field was edited then cleared; the name field was never
    // touched and must not be flagged yet.
    expect(find.text('Required'), findsOneWidget);
  });
}
