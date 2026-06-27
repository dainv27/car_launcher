import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const sizes = [
    Size(1024, 600),
    Size(1127, 676),
    Size(1280, 720),
    Size(1920, 720),
    Size(2560, 1080),
  ];

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  for (final size in sizes) {
    testWidgets('MediaCenterPage renders without overflow at $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            launcherServiceProvider.overrideWithValue(LauncherService(prefs)),
            sharedPreferencesProvider.overrideWithValue(prefs),
            carPlaySettingsProvider.overrideWith(
              (ref) => CarPlaySettingsNotifier(prefs),
            ),
          ],
          child: const MaterialApp(home: MediaCenterPage()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
