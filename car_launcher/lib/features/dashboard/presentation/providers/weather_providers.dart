import 'package:car_launcher/shared/data/weather_service.dart';
import 'package:car_launcher/shared/providers/shared_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for weather service
final weatherServiceProvider = Provider<WeatherService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final client = ref.watch(httpClientProvider);
  return WeatherService(prefs, client);
});

/// Provider for weather notifier
final weatherProvider = StateNotifierProvider<WeatherNotifier, AsyncValue<WeatherData?>>((ref) {
  final weatherService = ref.watch(weatherServiceProvider);
  return WeatherNotifier(weatherService);
});
