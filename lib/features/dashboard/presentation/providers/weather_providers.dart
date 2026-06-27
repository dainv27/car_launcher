import 'package:car_launcher/core/di/injection_container.dart';
import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for weather service — bridges get_it factory into Riverpod.
///
/// WeatherService construction (SharedPreferences + http.Client) is
/// registered in injection_container.dart as a factory.
final weatherServiceProvider = Provider<WeatherService>(
  (ref) => getIt<WeatherService>(),
);

/// Provider for weather notifier.
final weatherProvider = StateNotifierProvider<WeatherNotifier, AsyncValue<WeatherData?>>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  return WeatherNotifier(weatherService);
});
