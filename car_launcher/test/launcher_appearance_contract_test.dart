import 'dart:io';

import 'package:car_launcher/core/theme/launcher_appearance.dart';
import 'package:car_launcher/features/theme/presentation/providers/launcher_appearance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('launcher appearance notifier persists real selections', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notifier = LauncherAppearanceNotifier(prefs);
    await Future<void>.delayed(Duration.zero);

    await notifier.setThemeStyle(LauncherThemeStyle.electric);
    await notifier.setBackgroundStyle(LauncherBackgroundStyle.aurora);
    await notifier.setCustomWallpaperPath('/tmp/custom-wallpaper.png');

    final restored = LauncherAppearanceNotifier(prefs);
    await Future<void>.delayed(Duration.zero);
    expect(restored.state.themeStyle, LauncherThemeStyle.electric);
    expect(restored.state.backgroundStyle, LauncherBackgroundStyle.aurora);
    expect(restored.state.customWallpaperPath, '/tmp/custom-wallpaper.png');

    await restored.clearCustomWallpaper();
    final cleared = LauncherAppearanceNotifier(prefs);
    await Future<void>.delayed(Duration.zero);
    expect(cleared.state.customWallpaperPath, isNull);
  });

  test('launcher appearance schedule resolves theme by hour', () {
    expect(
      LauncherAppearanceSchedule.resolve(DateTime(2026, 6, 17, 9)).themeStyle,
      LauncherThemeStyle.glass,
    );
    expect(
      LauncherAppearanceSchedule.resolve(DateTime(2026, 6, 17, 18))
          .themeStyle,
      LauncherThemeStyle.electric,
    );
    expect(
      LauncherAppearanceSchedule.resolve(DateTime(2026, 6, 17, 23))
          .themeStyle,
      LauncherThemeStyle.dark,
    );
  });

  test('launcher appearance is persisted and applied below the router', () {
    final provider = File(
      'lib/features/theme/presentation/providers/launcher_appearance_provider.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();

    expect(provider, contains('SharedPreferences'));
    expect(provider, contains('keyLauncherThemeStyle'));
    expect(provider, contains('keyLauncherBackgroundStyle'));
    expect(main, contains('LauncherBackground'));
    expect(main, contains('effectiveLauncherAppearanceProvider'));
    expect(provider, isNot(contains("'setLauncherAppearance'")));
  });

  test('settings appearance controls the persisted launcher appearance', () {
    final settings = File(
      'lib/features/settings/presentation/settings_page.dart',
    ).readAsStringSync();

    expect(settings, contains('launcherAppearanceProvider'));
    expect(settings, contains('setThemeStyle'));
    expect(settings, contains('setBackgroundStyle'));
    expect(settings, contains('setCustomWallpaperPath'));
    expect(settings, contains("Key('settings-pick-wallpaper')"));
    expect(settings, contains("Key('settings-clear-wallpaper')"));
    expect(settings, isNot(contains("String _selectedTheme = 'Dark'")));
    expect(settings, isNot(contains('onTap: () {}')));
  });

  test('launcher background uses logo_1 as default wallpaper', () {
    final background = File(
      'lib/features/theme/presentation/widgets/launcher_background.dart',
    ).readAsStringSync();

    expect(background, contains('assets/images/logo_1.png'));
    expect(background, contains("Key('launcher-default-wallpaper')"));
    expect(background, contains("Key('launcher-custom-wallpaper')"));
  });

  test('primary launcher screens expose the global background', () {
    const paths = [
      'lib/features/dashboard/all_dashboard/map.dart',
      'lib/features/dashboard/all_dashboard/map_with_media.dart',
      'lib/features/dashboard/all_dashboard/map_with_youtube.dart',
      'lib/features/app_drawer/presentation/app_drawer_page.dart',
      'lib/features/media/presentation/media_center_page.dart',
      'lib/features/settings/presentation/settings_page.dart',
      'lib/features/settings/presentation/clock_network_settings_page.dart',
    ];

    for (final path in paths) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        isNot(contains('backgroundColor: CarPlayTheme.deepObsidian')),
        reason: path,
      );
      expect(
        source,
        isNot(
          contains('color: CarPlayTheme.deepObsidian,\n      child: SafeArea'),
        ),
        reason: path,
      );
    }
  });
}
