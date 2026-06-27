import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/core/theme/app_theme.dart';
import 'package:car_launcher/shared/constants/app_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.carlauncher/native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'getConnectivityStatus':
              return <String, dynamic>{};
            case 'getBatteryLevel':
              return 80;
            case 'getDeviceInfo':
              return <String, dynamic>{};
            case 'launchMapsWithYoutubeOnTop':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('LauncherService', () {
    late LauncherService launcher;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      launcher = LauncherService(prefs);
    });

    test('themeMode defaults to auto', () {
      expect(launcher.themeMode, AppThemeMode.auto);
    });

    test('setThemeMode persists the value', () async {
      await launcher.setThemeMode(AppThemeMode.night);
      expect(launcher.themeMode, AppThemeMode.night);

      await launcher.setThemeMode(AppThemeMode.day);
      expect(launcher.themeMode, AppThemeMode.day);
    });

    test(
      'launchMapsWithYoutubeOnTop delegates to native multi-window flow',
      () async {
        expect(await launcher.launchMapsWithYoutubeOnTop(), isTrue);
      },
    );
  });

  group('AppConstants', () {
    test('app name and version are correct', () {
      expect(AppConstants.appName, 'Car Launcher');
      expect(AppConstants.appVersion, '1.0.0');
    });
  });
}
