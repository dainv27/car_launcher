import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for weather service.
///
/// Built from the Riverpod-overridable [sharedPreferencesProvider] and
/// [httpClientProvider] rather than the get_it singleton so widget tests can
/// pump weather-bearing screens without booting the full DI container.
final weatherServiceProvider = Provider<WeatherService>(
  (ref) => WeatherService(
    ref.watch(sharedPreferencesProvider),
    ref.watch(httpClientProvider),
  ),
);

/// Provider for weather notifier.
final weatherProvider = StateNotifierProvider<WeatherNotifier, AsyncValue<WeatherData?>>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  return WeatherNotifier(weatherService);
});
