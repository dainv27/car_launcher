import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_media.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
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

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 720);
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
          filteredAppsProvider.overrideWithValue(const []),
          appsLoadingProvider.overrideWithValue(false),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
  }

  testWidgets('dashboard home implements the reference bento layout', (
    tester,
  ) async {
    await pumpScreen(tester, const MapWithMedia());

    expect(find.byKey(const Key('dashboard-native-sidebar-space')), findsNothing);
    expect(find.byKey(const Key('dashboard-map-card')), findsOne);
    expect(find.byKey(const Key('dashboard-media-card')), findsOne);
    expect(find.byKey(const Key('dashboard-weather-card')), findsOne);
    expect(find.byKey(const Key('top-bar-k3-logo')), findsOne);
    expect(find.byKey(const Key('top-bar-location-name')), findsOne);
    expect(find.byKey(const Key('dashboard-weather-temperature')), findsOne);
    expect(find.byKey(const Key('dashboard-clock-time')), findsOne);
    expect(find.text('SAN FRANCISCO'), findsNothing);
    expect(find.text('24°'), findsNothing);
    expect(find.text('Heading North-East'), findsNothing);
    expect(find.text('K3'), findsNothing);
  });

  testWidgets('navigation supports map-only and YouTube overlay designs', (
    tester,
  ) async {
    await pumpScreen(tester, const MapPage(showYoutube: false));
    expect(find.byKey(const Key('navigation-youtube-panel')), findsNothing);

    await pumpScreen(tester, const MapPage(showYoutube: true));
    expect(find.byKey(const Key('navigation-youtube-panel')), findsOne);
  });

  testWidgets('app drawer and media center do not reserve a taskbar rail', (
    tester,
  ) async {
    await pumpScreen(tester, const AppDrawerPage());
    expect(find.byKey(const Key('app-drawer-native-sidebar-space')), findsNothing);

    await pumpScreen(tester, const MediaCenterPage());
    expect(find.byKey(const Key('media-native-sidebar-space')), findsNothing);
  });
}
