import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_media.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map_with_youtube.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/carplay_settings_providers.dart';
import 'package:car_launcher/features/media/presentation/media_center_page.dart';
import 'package:car_launcher/features/settings/presentation/settings_page.dart';
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

  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen,
    Size size, {
    double devicePixelRatio = 1,
  }) async {
    tester.view.devicePixelRatio = devicePixelRatio;
    tester.view.physicalSize = size * devicePixelRatio;
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
    expect(
      tester.takeException(),
      isNull,
      reason: '${screen.runtimeType} $size',
    );
  }

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .clearAllTestValues();
  });

  const sizes = [
    Size(1024, 600),
    Size(1127, 676),
    Size(1280, 720),
    Size(1920, 720),
    Size(2560, 1080),
  ];
  const screens = <Widget>[
    MapWithMedia(),
    MapWithYoutube(),
    MapPage(showYoutube: true),
    AppDrawerPage(),
    MediaCenterPage(),
    SettingsPage(),
  ];

  for (final size in sizes) {
    for (final screen in screens) {
      testWidgets('${screen.runtimeType} renders without overflow at $size', (
        tester,
      ) async {
        await pumpAt(tester, screen, size);
      });
    }
  }

  for (final screen in screens) {
    testWidgets('${screen.runtimeType} renders without overflow on Bengal', (
      tester,
    ) async {
      await pumpAt(
        tester,
        screen,
        const Size(1920 / 1.4875, 720 / 1.4875),
        devicePixelRatio: 1.4875,
      );
    });
  }
}
