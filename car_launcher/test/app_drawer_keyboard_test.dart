import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/app_drawer/presentation/app_drawer_page.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app grid scrolls above the keyboard without resizing tiles', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          launcherServiceProvider.overrideWithValue(LauncherService(prefs)),
          sharedPreferencesProvider.overrideWithValue(prefs),
          filteredAppsProvider.overrideWithValue(const [
            {'appName': 'Maps', 'packageName': 'com.google.android.apps.maps'},
          ]),
          appsLoadingProvider.overrideWithValue(false),
        ],
        child: const MaterialApp(home: AppDrawerPage()),
      ),
    );
    await tester.pump();

    final grid = tester.widget<GridView>(
      find.byKey(const Key('app-drawer-app-grid')),
    );
    expect((grid.padding! as EdgeInsets).bottom, 348);
    expect(tester.takeException(), isNull);
  });
}
