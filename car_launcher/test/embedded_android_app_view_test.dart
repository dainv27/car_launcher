import 'package:car_launcher/features/layout/presentation/widgets/embedded_android_app_view.dart';
import 'package:car_launcher/features/dashboard/all_dashboard/map.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('passes package and CarCar-style display options to Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      const MaterialApp(
        home: EmbeddedAndroidAppView(
          packageName: 'com.google.android.youtube',
          paneId: 2,
          zOrderOnTop: true,
        ),
      ),
    );

    final embedded = tester.widget<EmbeddedAndroidAppView>(
      find.byType(EmbeddedAndroidAppView),
    );
    expect(embedded.packageName, 'com.google.android.youtube');
    expect(embedded.paneId, 2);
    expect(embedded.zOrderOnTop, isTrue);
    expect(find.byType(PlatformViewLink), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows fallback on non-Android platforms', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      const MaterialApp(
        home: EmbeddedAndroidAppView(
          packageName: 'com.google.android.apps.maps',
          paneId: 1,
        ),
      ),
    );

    expect(find.byType(AndroidView), findsNothing);
    expect(find.text('Embedded app requires Android'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('dashboard requests separate Maps and YouTube displays', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      const MaterialApp(home: MapPage()),
    );

    final appViews = tester
        .widgetList<EmbeddedAndroidAppView>(find.byType(EmbeddedAndroidAppView))
        .toList();
    expect(appViews, hasLength(2));
    expect(appViews[0].packageName, 'com.google.android.apps.maps');
    expect(appViews[0].paneId, 1);
    expect(appViews[0].zOrderOnTop, isTrue);
    expect(appViews[1].packageName, 'com.google.android.youtube');
    expect(appViews[1].paneId, 2);
    expect(appViews[1].zOrderOnTop, isTrue);

    debugDefaultTargetPlatformOverride = null;
  });
}
