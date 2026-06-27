import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/settings/presentation/settings_page.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('account settings opens the account detail immediately',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SettingsPage(initialCategory: 5),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Account'), findsWidgets);
    expect(find.text('Sign in to sync your preferences.'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('settings matches the 1920x720 reference layout', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1920, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          connectivityStatusProvider.overrideWith(
            (ref) => ConnectivityNotifier(
              LauncherService(prefs),
              const Stream<Map<String, dynamic>>.empty(),
            ),
          ),
        ],
        child: const MaterialApp(home: SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    final categoryRail = tester.getRect(
      find.byKey(const Key('settings-category-rail')),
    );
    final themeCard = tester.getRect(
      find.byKey(const Key('settings-theme-card')),
    );
    final quickCard = tester.getRect(
      find.byKey(const Key('settings-quick-card')),
    );

    expect(categoryRail.left, closeTo(11, 1));
    expect(categoryRail.width, 400);
    expect(themeCard.top, quickCard.top);
    expect(themeCard.right, lessThan(quickCard.left));
  });

  testWidgets('settings uses a top category grid on S60 layout', (tester) async {
    tester.view.physicalSize = const Size(1127, 676);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SettingsPage(initialCategory: 5)),
      ),
    );
    await tester.pump();

    final categoryGrid = tester.getRect(
      find.byKey(const Key('settings-s60-category-grid')),
    );
    final detailArea = tester.getRect(
      find.byKey(const Key('settings-detail-area')),
    );

    expect(categoryGrid.top, lessThan(detailArea.top));
    expect(categoryGrid.width, closeTo(detailArea.width, 1));
    expect(find.text('Account'), findsWidgets);
  });
}
