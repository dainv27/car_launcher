import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_media.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_youtube.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpDashboard(
    WidgetTester tester,
    Widget dashboard,
    Size size,
  ) async {
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
        child: MaterialApp(home: dashboard),
      ),
    );
    await tester.pump();
  }

  testWidgets('Dashboard01 expands YouTube without covering map controls', (
    tester,
  ) async {
    await pumpDashboard(tester, const MapPage(), const Size(1920, 720));

    final finder = find.byKey(const Key('navigation-youtube-panel'));
    final panel = tester.getSize(finder);
    expect(tester.getTopLeft(finder).dy, greaterThanOrEqualTo(80));
    expect(panel.height, greaterThan(620));
    expect(panel.width, greaterThan(650));
  });

  testWidgets('Dashboard02 gives most space to its actual cards', (
    tester,
  ) async {
    await pumpDashboard(tester, const MapWithMedia(), const Size(1920, 720));

    final map = tester.getSize(find.byKey(const Key('dashboard-map-card')));
    final media = tester.getSize(find.byKey(const Key('dashboard-media-card')));
    final weather = tester.getSize(
      find.byKey(const Key('dashboard-weather-card')),
    );
    expect(map.width, greaterThan(1180));
    expect(map.height, greaterThan(580));
    expect(media.width, greaterThan(580));
    expect(media.height, greaterThan(280));
    expect(weather.width, greaterThan(580));
    expect(weather.height, greaterThan(280));
  });

  testWidgets('Dashboard03 gives most space to Map and YouTube', (
    tester,
  ) async {
    await pumpDashboard(tester, const MapWithYoutube(), const Size(1920, 720));

    final map = tester.getSize(find.byKey(const Key('dashboard-map-card')));
    final youtube = tester.getSize(
      find.byKey(const Key('dashboard-youtube-card')),
    );
    expect(map.width, greaterThan(1050));
    expect(map.height, greaterThan(580));
    expect(youtube.width, greaterThan(700));
    expect(youtube.height, greaterThan(580));
    expect(map.width / youtube.width, inInclusiveRange(1.4, 1.7));
  });
}
