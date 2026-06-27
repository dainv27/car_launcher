import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');
  final releaseManifest = File('android/app/src/release/AndroidManifest.xml');
  final buildGradle = File('android/app/build.gradle.kts');
  final mainActivity = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/MainActivity.kt',
  );
  final bootReceiver = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/BootReceiver.kt',
  );
  final startupCoordinator = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
    'StartupCoordinator.kt',
  );
  final startupJobService = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
    'StartupJobService.kt',
  );
  final mapsPlatformView = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/platform_view/'
    'GoogleMapsPlatformView.kt',
  );
  final virtualDisplayView = File(
    'android/app/src/main/kotlin/com/carlauncher/car_launcher/embedding/'
    'VirtualDisplayAppView.kt',
  );
  final app = File('lib/main.dart');
  final topAppBar = File(
    'lib/features/dashboard/presentation/widgets/top_app_bar.dart',
  );
  final appDrawer = File(
    'lib/features/app_drawer/presentation/app_drawer_page.dart',
  );
  final appDrawerProviders = File(
    'lib/features/app_drawer/presentation/providers/app_drawer_providers.dart',
  );
  final mediaCenter = File(
    'lib/features/media/presentation/media_center_page.dart',
  );
  final navigationMapWidget = File(
    'lib/features/dashboard/presentation/widgets/navigation_map_widget.dart',
  );
  final youtubeWidget = File(
    'lib/features/dashboard/presentation/widgets/youtube_widget.dart',
  );
  final bottomStatusBar = File(
    'lib/features/dashboard/presentation/widgets/bottom_status_bar.dart',
  );

  test(
    'Android manifest exposes a normal app without launcher or overlays',
    () {
      final source = manifest.readAsStringSync();

      expect(source, contains('android.intent.category.LAUNCHER'));
      expect(source, isNot(contains('android.intent.category.HOME')));
      expect(source, isNot(contains('android.permission.SYSTEM_ALERT_WINDOW')));
      expect(source, isNot(contains('android.permission.FOREGROUND_SERVICE')));
      expect(source, isNot(contains('.SystemSidebarService')));
      expect(source, isNot(contains('.MediaOverlayService')));
    },
  );

  test('boot receiver waits for system dependencies before launch', () {
    final manifestSource = manifest.readAsStringSync();
    final receiverSource = bootReceiver.readAsStringSync();
    final coordinatorSource = startupCoordinator.readAsStringSync();
    final jobServiceSource = startupJobService.readAsStringSync();

    expect(
      manifestSource,
      contains('android.permission.RECEIVE_BOOT_COMPLETED'),
    );
    expect(manifestSource, contains('.BootReceiver'));
    expect(manifestSource, contains('.StartupJobService'));
    expect(manifestSource, contains('android.permission.BIND_JOB_SERVICE'));
    expect(manifestSource, contains('android.intent.action.BOOT_COMPLETED'));
    expect(
      manifestSource,
      contains('android.intent.action.LOCKED_BOOT_COMPLETED'),
    );
    expect(receiverSource, contains('StartupCoordinator.scheduleStartupCheck'));
    expect(coordinatorSource, contains('JobScheduler'));
    expect(coordinatorSource, contains('INITIAL_BOOT_DELAY_MS = 45_000L'));
    expect(coordinatorSource, contains('MAX_ATTEMPTS = 20'));
    expect(coordinatorSource, contains('userManager?.isUserUnlocked'));
    expect(coordinatorSource, contains('com.google.android.apps.maps'));
    expect(coordinatorSource, contains('com.google.android.youtube'));
    expect(coordinatorSource, contains('startActivity'));
    expect(jobServiceSource, contains('readStartupReadiness'));
    expect(jobServiceSource, contains('launchMainActivity'));
  });

  test('native activity has no launcher-role or overlay API', () {
    final source = mainActivity.readAsStringSync();

    expect(source, isNot(contains('"isDefaultLauncher"')));
    expect(source, isNot(contains('"setDefaultLauncher"')));
    expect(source, isNot(contains('"showSystemSidebar"')));
    expect(source, isNot(contains('"showMediaOverlay"')));
    expect(source, isNot(contains('SystemSidebarService')));
    expect(source, isNot(contains('MediaOverlayService')));
    expect(source, isNot(contains('processRouteRequest')));
    expect(source, isNot(contains('"onRouteRequest"')));
  });

  test('release build does not require platform signing identity', () {
    final releaseSource = releaseManifest.readAsStringSync();
    final gradleSource = buildGradle.readAsStringSync();

    expect(releaseSource, isNot(contains('android.uid.system')));
    expect(releaseSource, isNot(contains('android:sharedUserId')));
    expect(gradleSource, isNot(contains('throw GradleException')));
    expect(gradleSource, contains('signingConfigs.getByName("debug")'));
  });

  test('app uses full-width content without a persistent taskbar', () {
    final source = manifest.readAsStringSync();
    final appSource = app.readAsStringSync();
    final topBarSource = topAppBar.readAsStringSync();

    expect(appSource, isNot(contains('Sidebar()')));
    expect(appSource, isNot(contains('sidebarWidth')));
    expect(topBarSource, contains("context.go('/settings')"));
    expect(topBarSource, contains("context.go('/')"));
    expect(topBarSource, contains("context.go('/apps')"));
    expect(topBarSource, contains("context.go('/media')"));
    expect(topBarSource, contains("context.go('/navigation')"));
    expect(topBarSource, contains("Key('top-bar-settings')"));
    expect(topBarSource, contains("Key('top-bar-home')"));
    expect(topBarSource, contains("Key('top-bar-clock')"));
    expect(topBarSource, contains('ref.watch(clockProvider)'));
    expect(topBarSource, isNot(contains("Key('top-bar-clock-date')")));
    expect(topBarSource, isNot(contains("Key('top-bar-clock-accent')")));
    expect(topBarSource, isNot(contains("'LOCAL'")));
    expect(topBarSource, isNot(contains('_formatDate')));
    expect(topBarSource, isNot(contains('LinearGradient')));
    expect(topBarSource, isNot(contains('BoxShadow')));
    expect(
      bottomStatusBar.readAsStringSync(),
      isNot(contains('Internet validated')),
    );
    expect(
      bottomStatusBar.readAsStringSync(),
      isNot(contains('Internet unavailable')),
    );
    expect(appDrawer.readAsStringSync(), contains("Key('apps-settings')"));
    expect(mediaCenter.readAsStringSync(), contains("Key('media-settings')"));
    expect(source, contains('android:launchMode="singleTop"'));
    expect(source, isNot(contains('android:taskAffinity=')));
    expect(source, isNot(contains('android:alwaysRetainTaskState=')));
    expect(source, isNot(contains('android:clearTaskOnLaunch=')));
  });

  test('removed overlay source files stay absent', () {
    for (final name in ['SystemSidebarService.kt', 'MediaOverlayService.kt']) {
      expect(
        File(
          'android/app/src/main/kotlin/com/carlauncher/car_launcher/$name',
        ).existsSync(),
        isFalse,
        reason: name,
      );
    }
  });

  test('Maps overlay mode falls back to fullscreen launch', () {
    final source = mapsPlatformView.readAsStringSync();

    expect(source, contains('showFullscreenLaunchFallback'));
    expect(source, contains('rootView.post { openGoogleMapsFullscreen() }'));
    expect(source, isNot(contains('MediaOverlayService')));
    expect(source, isNot(contains('Settings.canDrawOverlays')));
    expect(source, isNot(contains('ACTION_MANAGE_OVERLAY_PERMISSION')));
  });

  test('dashboard runs maps and youtube as virtual display surfaces', () {
    final navigation = navigationMapWidget.readAsStringSync();
    final youtube = youtubeWidget.readAsStringSync();
    final activity = mainActivity.readAsStringSync();

    expect(activity, contains('registerViewFactory("virtual_display_app"'));
    expect(activity, isNot(contains('youtube_webview')));
    expect(navigation, contains('EmbeddedAndroidAppView'));
    expect(youtube, contains('EmbeddedAndroidAppView'));
    expect(navigation, contains("packageName: 'com.google.android.apps.maps'"));
    expect(youtube, contains("packageName: 'com.google.android.youtube'"));
    expect(navigation, contains('paneId: 1'));
    expect(youtube, contains('paneId: 2'));
    expect(navigation, isNot(contains("viewType: 'google_maps_taskview'")));
    expect(youtube, isNot(contains("viewType: 'youtube_webview'")));
    expect(
      navigation,
      isNot(contains("launchApp('com.google.android.apps.maps')")),
    );
    expect(youtube, isNot(contains("launchApp('com.google.android.youtube')")));
  });

  test('virtual display skips trusted flags without privileged permission', () {
    final source = virtualDisplayView.readAsStringSync();

    expect(source, contains('createTrustedVirtualDisplayIfAllowed'));
    expect(source, contains('"android.permission.ADD_TRUSTED_DISPLAY"'));
    expect(
      source,
      contains(
        'if (!hasPermission("android.permission.ADD_TRUSTED_DISPLAY")) return null',
      ),
    );
    expect(source, contains('flags = COMPAT_VIRTUAL_DISPLAY_FLAGS'));
  });

  test('app drawer refreshes when Android packages change', () {
    final providerSource = appDrawerProviders.readAsStringSync();
    final activitySource = mainActivity.readAsStringSync();
    final receiverSource = File(
      'android/app/src/main/kotlin/com/carlauncher/car_launcher/'
      'AppPackageChangedReceiver.kt',
    ).readAsStringSync();
    expect(providerSource, contains('NativeBridge.onEvent<Map>'));
    expect(providerSource, contains("'app_package_changed'"));
    expect(providerSource, contains('refreshSoon'));
    expect(activitySource, contains('registerAppPackageChangedReceiver'));
    expect(activitySource, contains('Intent.ACTION_PACKAGE_ADDED'));
    expect(activitySource, contains('Intent.ACTION_PACKAGE_REMOVED'));
    expect(activitySource, contains('"app_package_changed"'));
    expect(receiverSource, contains('package com.carlauncher.car_launcher'));
  });
}
