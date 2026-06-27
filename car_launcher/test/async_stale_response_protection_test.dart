import 'dart:async';

import 'package:car_launcher/features/launcher/data/launcher_service.dart';
import 'package:car_launcher/features/app_drawer/presentation/providers/app_drawer_providers.dart';
import 'package:car_launcher/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:car_launcher/shared/data/location_service.dart';
import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'weather_city': 'Initial'});
    prefs = await SharedPreferences.getInstance();
  });

  test('installed apps ignores an older request completing last', () async {
    final launcher = _ControlledLauncherService(prefs);
    final first = Completer<List<Map<String, String>>>();
    final second = Completer<List<Map<String, String>>>();
    launcher.installedAppsResponses.addAll([first.future, second.future]);
    final notifier = InstalledAppsNotifier(launcher);
    addTearDown(notifier.dispose);

    final refresh = notifier.refresh();
    second.complete([
      {'appName': 'New', 'packageName': 'new'},
    ]);
    await refresh;
    first.complete([
      {'appName': 'Old', 'packageName': 'old'},
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.apps.single['packageName'], 'new');
  });

  test('connectivity event invalidates an older refresh', () async {
    final launcher = _ControlledLauncherService(prefs);
    final response = Completer<Map<String, dynamic>>();
    launcher.connectivityResponses.add(response.future);
    final events = StreamController<dynamic>();
    final notifier = ConnectivityNotifier(launcher, events.stream);
    addTearDown(notifier.dispose);
    addTearDown(events.close);

    events.add({'source': 'event'});
    await Future<void>.delayed(Duration.zero);
    response.complete({'source': 'refresh'});
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state['source'], 'event');
  });

  test('weather ignores an older request completing last', () async {
    final service = _ControlledWeatherService(prefs);
    final first = Completer<WeatherData?>();
    final second = Completer<WeatherData?>();
    service.cityResponses.addAll([first.future, second.future]);
    final notifier = WeatherNotifier(service);
    addTearDown(notifier.dispose);

    final refresh = notifier.refresh();
    second.complete(_weather('New'));
    await refresh;
    first.complete(_weather('Old'));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.valueOrNull?.cityName, 'New');
  });

  test('location ignores an older error completing last', () async {
    const channel = MethodChannel('com.carlauncher/native');
    final first = Completer<Object?>();
    final second = Completer<Object?>();
    final responses = <Future<Object?>>[first.future, second.future];
    var call = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => responses[call++]);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final notifier = LocationNotifier();
    addTearDown(notifier.dispose);

    final refresh = notifier.refresh();
    second.complete({
      'status': 'ok',
      'displayName': 'New',
      'latitude': 1.0,
      'longitude': 2.0,
    });
    await refresh;
    first.completeError(PlatformException(code: 'old'));
    await Future<void>.delayed(Duration.zero);

    expect(notifier.state.valueOrNull?.displayName, 'New');
  });

  test('pending completions do not write after disposal', () async {
    final launcher = _ControlledLauncherService(prefs);
    final apps = Completer<List<Map<String, String>>>();
    launcher.installedAppsResponses.add(apps.future);
    final notifier = InstalledAppsNotifier(launcher);

    notifier.dispose();
    apps.complete(const []);
    await Future<void>.delayed(Duration.zero);
  });
}

WeatherData _weather(String city) => WeatherData(
  cityName: city,
  temperature: 20,
  description: 'clear',
  iconCode: '01d',
  humidity: 50,
  windSpeed: 1,
);

class _ControlledLauncherService extends LauncherService {
  _ControlledLauncherService(super.prefs);

  final installedAppsResponses = <Future<List<Map<String, String>>>>[];
  final connectivityResponses = <Future<Map<String, dynamic>>>[];

  @override
  Future<List<Map<String, String>>> getInstalledApps() =>
      installedAppsResponses.removeAt(0);

  @override
  Future<Map<String, dynamic>> getConnectivityStatus() =>
      connectivityResponses.removeAt(0);
}

class _ControlledWeatherService extends WeatherService {
  _ControlledWeatherService(SharedPreferences prefs)
    : super(prefs, http.Client());

  final cityResponses = <Future<WeatherData?>>[];

  @override
  Future<WeatherData?> fetchWeatherByCity(String cityName) =>
      cityResponses.removeAt(0);
}
